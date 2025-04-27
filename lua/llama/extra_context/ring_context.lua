---@class RingContext
---@field extra_ctx table Extra context information
local M = {
  extra_ctx = {},
}

local config = require("llama.config")
local http = require("llama.http")
local json = vim.fn.json_encode
local logger = require("llama.logger")

local ring_chunks = {} -- Buffer of processed chunks
local ring_queued = {} -- Queue of chunks waiting to be processed
local ring_n_evict = 0 -- Counter for evicted chunks
local t_last_move = vim.loop.hrtime() -- Timestamp of last cursor movement
local pos_y_pick = -1 -- last y where we picked a chunk

---Computes similarity between two text chunks
---@param c0 string[] First chunk of text
---@param c1 string[] Second chunk of text
---@return number Similarity score between 0 and 1
local function chunk_sim(c0, c1)
  local lines0 = #c0
  local lines1 = #c1
  local common = 0

  for _, line0 in ipairs(c0) do
    for _, line1 in ipairs(c1) do
      if line0 == line1 then
        common = common + 1
        break
      end
    end
  end

  return 2.0 * common / (lines0 + lines1)
end

---Picks a random chunk of text and queues it for processing
---@param text string[] Text to process
---@param no_mod boolean Whether to skip modified buffers
---@param do_evict boolean Whether to evict similar chunks
local function pick_chunk(text, no_mod, do_evict)
  -- Skip if extra context is disabled
  if config.values.ring_n_chunks <= 0 then
    return
  end

  -- Skip modified buffers or non-file buffers
  if
    no_mod
    and (
      vim.bo.modified
      or not vim.api.nvim_get_option_value("buflisted", { buf = 0 })
      or not vim.loop.fs_stat(vim.fn.expand("%"))
    )
  then
    return
  end

  -- Skip very small chunks
  if #text < 3 then
    return
  end

  -- Select chunk based on size
  local chunk
  if #text + 1 < config.values.ring_chunk_size then
    chunk = text
  else
    math.randomseed(os.time())
    local l0 = math.random(0, math.max(0, #text - config.values.ring_chunk_size / 2))
    local l1 = math.min(l0 + config.values.ring_chunk_size / 2, #text)

    chunk = {}
    for i = l0 + 1, l1 do
      table.insert(chunk, text[i])
    end
  end

  local chunk_str = table.concat(chunk, "\n") .. "\n"

  -- Check for existing chunks
  local exist = false
  for i = 1, #ring_chunks do
    if vim.deep_equal(ring_chunks[i].data, chunk) then
      exist = true
      break
    end
  end

  for i = 1, #ring_queued do
    if vim.deep_equal(ring_queued[i].data, chunk) then
      exist = true
      break
    end
  end

  if exist then
    return
  end

  -- Evict similar chunks if requested
  if do_evict then
    for i = #ring_queued, 1, -1 do
      if chunk_sim(ring_queued[i].data, chunk) > 0.9 then
        table.remove(ring_queued, i)
        ring_n_evict = ring_n_evict + 1
      end
    end

    for i = #ring_chunks, 1, -1 do
      if chunk_sim(ring_chunks[i].data, chunk) > 0.9 then
        table.remove(ring_chunks, i)
        ring_n_evict = ring_n_evict + 1
      end
    end
  end

  -- Maintain queue size limit
  if #ring_queued == config.values.ring_n_chunks then
    table.remove(ring_queued, 1)
  end

  -- Add new chunk to queue
  table.insert(ring_queued, {
    data = chunk,
    str = chunk_str,
    time = vim.fn.reltime(),
    filename = vim.fn.expand("%"),
  })
end

---Gets the current extra context information
---@return table Extra context data
local function get_extra_context()
  local extra_ctx = {}
  for _, chunk in ipairs(ring_chunks) do
    table.insert(extra_ctx, {
      text = chunk.str,
      time = chunk.time,
      filename = chunk.filename,
    })
  end
  return extra_ctx
end

---Updates the ring buffer by processing queued chunks
---Called periodically based on ring_update_ms configuration
local function ring_update()
  vim.defer_fn(ring_update, config.values.ring_update_ms)

  -- Skip update if not in normal mode or cursor recently moved
  if
    vim.api.nvim_get_mode().mode ~= "n"
    and vim.fn.reltimefloat(vim.fn.reltime(t_last_move)) < 3.0
  then
    return
  end

  if #ring_queued == 0 then
    return
  end

  -- Process queued chunk
  if #ring_chunks == config.values.ring_n_chunks then
    table.remove(ring_chunks, 1)
  end

  table.insert(ring_chunks, table.remove(ring_queued, 1))

  -- Update extra context
  M.extra_ctx = get_extra_context()

  -- Send update to API
  local request_body = json({
    input_prefix = "",
    input_suffix = "",
    input_extra = M.extra_ctx,
    prompt = "",
    n_predict = 0,
    temperature = 0.0,
    stream = false,
    samplers = {},
    cache_prompt = true,
    t_max_prompt_ms = 1,
    t_max_predict_ms = 1,
    response_fields = { "" },
  })

  local headers = {
    ["Content-Type"] = "application/json",
  }

  if config.values.api_key and config.values.api_key ~= "" then
    headers["Authorization"] = "Bearer " .. config.values.api_key
  end

  http.post(config.values.endpoint, request_body, headers, function() end, function(err)
    vim.schedule(function()
      logger.error("Error in ring context update: ")
    end)
  end)
end

---Sets up autocommands for context gathering
local function setup_autocommands()
  local group = vim.api.nvim_create_augroup("LlamaContextGather", { clear = true })

  -- Track cursor movement
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    callback = function()
      t_last_move = vim.fn.reltime()

      -- Get current cursor position
      local pos_y = vim.fn.line(".")
      local delta_y = math.abs(pos_y - pos_y_pick)

      -- Only gather chunks if cursor has moved significantly
      if delta_y > 32 then
        local max_y = vim.fn.line("$")

        -- Expand prefix context
        local prefix_start = math.max(1, pos_y - config.values.ring_scope)
        local prefix_end = math.max(1, pos_y - config.values.n_prefix)
        local prefix_lines =
          vim.api.nvim_buf_get_lines(0, prefix_start - 1, prefix_end, false)
        pick_chunk(prefix_lines, false, false)

        -- Gather suffix context
        local suffix_start = math.min(max_y, pos_y + config.values.n_suffix)
        local suffix_end = math.min(
          max_y,
          pos_y + config.values.n_suffix + config.values.ring_chunk_size
        )
        local suffix_lines =
          vim.api.nvim_buf_get_lines(0, suffix_start - 1, suffix_end, false)
        pick_chunk(suffix_lines, false, false)

        pos_y_pick = pos_y
      end
    end,
  })

  -- Gather chunks on yank
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    callback = function()
      local event = vim.v.event
      if event.operator == "y" then
        pick_chunk(event.regcontents, false, true)
      end
    end,
  })

  -- Gather chunks on buffer enter, leave and write
  vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave", "BufWritePost" }, {
    group = group,
    callback = function()
      local start_line =
        math.max(1, vim.fn.line(".") - math.floor(config.values.ring_chunk_size / 2))
      local end_line = math.min(
        vim.fn.line(".") + math.floor(config.values.ring_chunk_size / 2),
        vim.fn.line("$")
      )
      local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
      pick_chunk(lines, true, true)
    end,
  })
end

---Initializes the ring context system
function M.setup()
  ring_chunks = {}
  ring_queued = {}
  ring_n_evict = 0

  setup_autocommands()
  ring_update()
end

return M
