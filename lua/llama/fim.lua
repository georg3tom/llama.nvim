local config = require("llama.config")
local utils = require("llama.utils")
local curl = require("plenary.curl")
local keymaps = require("llama.keymaps")
local cache = require("llama.cache")
local logger = require("llama.logger")
local json = vim.fn.json_encode

local M = {
	current_job = nil,
	can_accept = false,
	can_show = false,
	hint_shown = false,
	cache = cache.new(config.values.max_cache_keys),
	fim_data = {
		line = 0,
		col = 0,
		line_cur = "",
		content = {},
	},
	ns_id = vim.api.nvim_create_namespace("fim_ns"),
}

--- @param line integer  Current line number.
--- @param col integer   Current column number.
function M.can_fim(line, col)
	local line_cur = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]

	if line_cur == nil then
		return false
	end

	-- Ensure cursor is at the end of the line
	if col ~= #line_cur then
		return false
	end

	-- Check if there is a non-space characterin the current line
	if line_cur:match("^%s*$") then
		return false
	end

	return true
end

function M._can_show()
	if not M.can_show then
		return false
	end

	if #M.fim_data.content == {} then
		return false
	end
	return true
end

function M.show()
	if not M._can_show() then
		return
	end

	M.hide()

	local virt_lines = {}
	for i = 2, #M.fim_data.content do
		virt_lines[i - 1] = { { M.fim_data.content[i], "Comment" } }
	end
	vim.api.nvim_buf_set_extmark(0, M.ns_id, M.fim_data.line - 1, M.fim_data.col, {
		virt_text = { { M.fim_data.content[1], "Comment" } },
		virt_lines = virt_lines,
		virt_text_pos = "inline",
	})
	keymaps.create_keymaps()
	M.hint_shown = true
	M.can_accept = true
end

--- @param use_cache boolean
function M.complete(use_cache)
	M.hide()
	local current_job = vim.loop.hrtime()
	M.current_job = vim.deepcopy(current_job)
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	if not M.can_fim(line, col) then
		return
	end
	M.fim_data.line = line
	M.fim_data.col = col
	M.fim_data.line_cur = vim.fn.getline(line)

	local local_ctx = utils.get_local_context(line, col)
	local extra_ctx = {}

	if use_cache then
		local cached_result = M.cache:get_cached_completion(local_ctx)
		if cached_result then
			M.fim_data.content = vim.split(cached_result, "\n", { plain = true })
			M.show()
			return
		end
	end

	local request_body = json({
		input_prefix = local_ctx.prefix,
		input_suffix = local_ctx.suffix,
		input_extra = extra_ctx,
		prompt = local_ctx.middle,
		n_predict = config.values.n_predict,
		n_indent = config.values.indent,
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

	curl.post(config.values.endpoint, {
		body = request_body,
		headers = headers,
		callback = function(response)
			if M.server_callback then
				vim.schedule(function()
					M.server_callback(local_ctx, response, current_job)
				end)
			end
		end,
		on_error = function(err)
			vim.schedule(function()
				logger.error(err.message)
			end)
		end,
	})
end

function M.server_callback(local_ctx, response, current_job)
	local ok, data = pcall(vim.fn.json_decode, response.body)
	if not ok then
		logger.warn("Failed to parse JSON response")
		return
	end
	local content = data.content
	content = utils.preprocess_content(content)
	if content then
		M.cache:add(local_ctx, content)
		if current_job ~= M.current_job then
			return
		end
		M.fim_data.content = vim.split(content, "\n", { plain = true })
		M.show()
	else
		M.fim_data.content = {}
		logger.info("No content in response")
	end
end

--- @param accept_type string
function M.accept(accept_type)
	if not M.can_accept then
		return
	end
	local line = M.fim_data.line
	local col = M.fim_data.col
	local content = M.fim_data.content
	local first_line = content[1]

	if accept_type == "word" then
		first_line = first_line:match("%s*(%S+)")
	end
	-- set the current line. default behaviour for accept_type == line
	vim.api.nvim_buf_set_text(0, line - 1, col, line - 1, col, { first_line })
	vim.api.nvim_win_set_cursor(0, { line, col + #first_line })

	-- If there are more lines, insert them after the first line
	if accept_type == "full" and #content > 1 then
		table.remove(content, 1)
		vim.api.nvim_buf_set_lines(0, line, line, false, content)
		vim.api.nvim_win_set_cursor(0, { line + #content, #content[#content] + 1 })
	end
	M.hide()
end

function M.hide()
	if not M.hint_shown then
		return
	end
	keymaps.remove_keymaps()
	M.hint_shown = false
	M.can_accept = false

	vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
end

return M
