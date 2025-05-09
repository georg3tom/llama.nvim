local config = require("llama.config")
local utils = require("llama.utils")
local http = require("llama.http")
local keymaps = require("llama.keymaps")
local cache = require("llama.cache")
local logger = require("llama.logger")
local json = vim.fn.json_encode
local ring_context = require("llama.extra_context.ring_context")

-- Initialize ring context
ring_context.setup()

local M = {}

-- Private state
---@type number|nil
local last_job = nil
---@type number|nil
local current_job = nil
---@type boolean
local hint_shown = false
local fim_cache = cache.new(config.values.max_cache_keys)
local timer = nil
local fim_data = {
  line = 0,
  col = 0,
  line_cur = "",
  content = {},
}
---@type number
local ns_id = vim.api.nvim_create_namespace("fim_ns")

---Checks if FIM (Fill-in-Middle) completion can be performed at the given position
---@param line number The line number to check
---@param col number The column number to check
---@return boolean True if FIM can be performed, false otherwise
local function can_fim(line, col)
  local file_path = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

  -- If the buffer is readonly or has an associated with a local file path
  if vim.bo.readonly or file_path == "" then
    return false
  end

  local line_cur = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
  if line_cur == nil then
    return false
  end

  -- Ensure cursor is at the end of the line
  -- if col ~= #line_cur then
  --  return false
  -- end

  -- Check if there is a non-space characterin the current line
  -- if line_cur:match("^%s*$") then
  --   return false
  -- end

  return true
end

local function _can_show()
  if not M.can_show then
    return false
  end

  if #fim_data.content == 0 then
    return false
  end
  return true
end

---Shows the FIM hint with virtual text
local function show()
  M.hide()
  if not _can_show() then
    return
  end

  local virt_lines = {}
  for i = 2, #fim_data.content do
    virt_lines[i - 1] = { { fim_data.content[i], "Comment" } }
  end
  vim.api.nvim_buf_set_extmark(0, ns_id, fim_data.line - 1, fim_data.col, {
    virt_text = { { fim_data.content[1], "Comment" } },
    virt_lines = virt_lines,
    virt_text_pos = "inline",
  })
  keymaps.create_keymaps()
  hint_shown = true
  ring_context.gather_context()
end

local server_callback = vim.schedule_wrap(function(local_ctx, response)
  local ok, data = pcall(vim.fn.json_decode, response.body)
  if not ok then
    logger.warn("Failed to parse JSON response")
    return
  end

  local content = data.content
  content = utils.preprocess_content(content, local_ctx.indent)

  if not content then
    fim_data.content = {}
    logger.info("No content in response")
    return
  end

  fim_cache:add(local_ctx, content)
  fim_data.content = vim.split(content, "\n", { plain = true })
  show()
end)

-- Public API
M.can_show = false

---Accepts the FIM completion based on the specified type
---@param accept_type string The type of acceptance: "word", "line", or "full"
function M.accept(accept_type)
  if not hint_shown then
    return
  end

  local line = fim_data.line
  local col = fim_data.col
  local content = fim_data.content
  local first_line = content[1]

  if accept_type == "word" then
    first_line = first_line:match("^(%s*%S+)")
  end
  -- set the current line. default behaviour for accept_type == line
  if first_line then
    vim.api.nvim_buf_set_text(0, line - 1, col, line - 1, col, { first_line })
    vim.api.nvim_win_set_cursor(0, { line, col + #first_line })
  end

  -- If there are more lines, insert them after the first line
  if accept_type == "full" and #content > 1 then
    table.remove(content, 1)
    vim.api.nvim_buf_set_lines(0, line, line, false, content)
    vim.api.nvim_win_set_cursor(0, { line + #content, #content[#content] + 1 })
  end
  M.hide()
end

---Checks if the current input matches the existing completion
---@param line number The current line number
---@param col number The current column number
---@return boolean True if the input matches and was handled, false otherwise
local function check_input_match(line, col)
  -- Early return if no completion content available
  if #fim_data.content == 0 then
    return false
  end

  local current_line = vim.fn.getline(line)
  local prev_line, prev_col = fim_data.line, fim_data.col

  -- Handle movement to next line
  if line == prev_line + 1 and fim_data.content[1] == "" then
    table.remove(fim_data.content, 1)

    if #fim_data.content == 0 then
      return false
    end

    -- Check if text before cursor matches prediction start
    local text_before_cursor = current_line:sub(1, col)
    if #text_before_cursor > 0 then
      local completion_prefix = fim_data.content[1]:sub(1, #text_before_cursor)
      if text_before_cursor ~= completion_prefix then
        return false
      end
      fim_data.content[1] = fim_data.content[1]:sub(#text_before_cursor + 1)
    end

    -- Update tracking data
    fim_data.line, fim_data.col, fim_data.line_cur = line, col, current_line
    show()
    return true
  end

  -- Handle cursor movement within same line
  if line ~= prev_line or col <= prev_col then
    return false
  end

  local added_text = current_line:sub(prev_col + 1, col)
  local completion_prefix = fim_data.content[1]:sub(1, #added_text)

  if added_text ~= completion_prefix then
    return false
  end

  fim_data.content[1] = fim_data.content[1]:sub(#added_text + 1)

  fim_data.line, fim_data.col, fim_data.line_cur = line, col, current_line

  -- Handle completion of current segment
  if fim_data.content[1] == "" then
    if #fim_data.content == 1 then
      fim_data.content = {}
      return false
    end
    table.remove(fim_data.content, 1)
  end

  show()
  return true
end

---debounce wrapper around complete()
---@param use_cache boolean Whether to use cached results if available
function M.debounce_complete(use_cache)
  -- check if the input matches the current completion
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  if not can_fim(line, col) then
    return
  end

  if check_input_match(line, col) then
    return
  end

  fim_data.line = line
  fim_data.col = col
  fim_data.line_cur = vim.fn.getline(line)
  fim_data.content = {}

  local local_ctx = utils.get_local_context(line, col)

  if use_cache then
    local cached_result = fim_cache:get_cached_completion(local_ctx)
    if cached_result then
      fim_data.content = vim.split(cached_result, "\n", { plain = true })
      show()
      return
    end
  end

  if M.timer then
    M.timer:stop()
    M.timer:close()
  end

  M.timer = vim.loop.new_timer()
  M.timer:start(100, 0, function()
    vim.schedule(function()
      M.complete(local_ctx)
    end)
  end)
end

---Completes the FIM request, either using cache or making a new request
---@param local_ctx table the local ctx
function M.complete(local_ctx)
  M.hide()

  if current_job then
    current_job:kill(15)
    current_job = nil
  end

  local extra_ctx = ring_context.extra_ctx
  local request_body = json({
    input_prefix = local_ctx.prefix,
    input_suffix = local_ctx.suffix,
    input_extra = extra_ctx,
    prompt = local_ctx.middle,
    n_predict = config.values.n_predict,
    n_indent = local_ctx.indent,
    top_k = 40,
    top_p = 0.90,
    stream = false,
    samplers = { "top_k", "top_p", "infill" },
    cache_prompt = true,
    t_max_prompt_ms = config.values.t_max_prompt_ms,
    t_max_predict_ms = config.values.t_max_predict_ms,
    response_fields = {
      "content",
    },
  })

  local headers = {
    ["Content-Type"] = "application/json",
  }

  if config.values.api_key and config.values.api_key ~= "" then
    headers["Authorization"] = "Bearer " .. config.values.api_key
  end

  current_job = http.post(
    config.values.endpoint,
    request_body,
    headers,
    function(response)
      server_callback(local_ctx, response)
    end,
    function(err)
      vim.schedule(function()
        logger.error(err.message)
      end)
    end
  )
end

---Hides the FIM hint and cleans up related resources
function M.hide()
  if not hint_shown then
    return
  end
  keymaps.remove_keymaps()
  hint_shown = false
  vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
end

return M
