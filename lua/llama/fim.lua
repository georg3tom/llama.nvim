local config = require("llama.config")
local cache = require("llama.cache")
local utils = require("llama.utils")
local curl = require("plenary.curl")
local keymaps = require("llama.keymaps")
local json = vim.fn.json_encode

local M = {
	current_job = nil,
	enabled = false,
	hint_shown = false,
	fim_data = {
		line = 0,
		col = 0,
		line_cur = "",
		content = {},
	},
	ns_id = vim.api.nvim_create_namespace("fim_ns"),
}

--- @param is_auto boolean
--- @param use_cache boolean
function M.complete_inline(is_auto, use_cache)
	if M.hint_shown and not is_auto then
		M.hide()
		return ""
	end

	M.complete(is_auto, {}, use_cache)
	return ""
end

function M.can_accept()
	if M.enabled == false then
		return false
	end
	return true
end

function M.can_fim(line, col)
	local line_cur = vim.api.nvim_get_current_line() -- Get current line text

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

function M.show()
	M.hide()
	if #M.fim_data.content == {} or M.enabled == false then
		return
	end
	M.hint_shown = true
	local line, col = unpack(vim.api.nvim_win_get_cursor(0)) -- Get cursor position
	line = line - 1 -- Convert to 0-based index

	local virt_lines = {}
	for i = 2, #M.fim_data.content do
		virt_lines[i - 1] = { { M.fim_data.content[i], "Comment" } }
	end
	vim.api.nvim_buf_set_extmark(0, M.ns_id, line, col, {
		virt_text = { { M.fim_data.content[1], "Comment" } },
		virt_lines = virt_lines,
		virt_text_pos = "inline",
	})
	keymaps.create_keymaps()
end

--- @param is_auto boolean
--- @param prev table
--- @param use_cache boolean
function M.complete(is_auto, prev, use_cache)
	local current_job = vim.loop.hrtime()
	M.current_job = vim.deepcopy(current_job)
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	if not M.can_fim(line, col) then
		return
	end
	M.fim_data.line = line
	M.fim_data.col = col
	M.fim_data.line_cur = vim.fn.getline(line)

	local ctx_local = utils.get_local_context(line, col, prev)
	local extra_ctx = {}

	local request_body = json({
		input_prefix = ctx_local.prefix,
		input_suffix = ctx_local.suffix,
		input_extra = extra_ctx,
		prompt = ctx_local.middle,
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
			"timings/prompt_n",
			"timings/prompt_ms",
			"timings/prompt_per_token_ms",
			"timings/prompt_per_second",
			"timings/predicted_n",
			"timings/predicted_ms",
			"timings/predicted_per_token_ms",
			"timings/predicted_per_second",
			"truncated",
			"tokens_cached",
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
					M.server_callback(response, current_job)
				end)
			end
		end,
	})
end

function M.server_callback(response, current_job)
	if current_job ~= M.current_job then
		return
	end
	if response.status ~= 200 then
		print("Error: HTTP " .. response.status)
		return
	end

	local ok, data = pcall(vim.fn.json_decode, response.body)
	if not ok then
		print("Failed to parse JSON response")
		return
	end

	if data.content then
		if not M.can_accept(data.content) then
			return
		end
		local content = utils.preprocess_content(data.content)
		M.fim_data.content = vim.split(content, "\n", { plain = true })
		M.show()
	else
		M.fim_data.content = {}
		print("No content in response")
	end
end

--- @param accept_type string
function M.accept(accept_type)
	M.hide()
	keymaps.remove_keymaps()
	local line = M.fim_data.line
	local col = M.fim_data.col
	local line_cur = M.fim_data.line_cur
	local content = M.fim_data.content
	if accept_type == "full" then
		local first_line = content[1]

		vim.api.nvim_buf_set_text(0, line - 1, col, line - 1, col, { first_line })
		vim.api.nvim_win_set_cursor(0, { line, col + #first_line })

		-- If there are more lines, insert them after the first line
		if #content > 1 then
			table.remove(content, 1)
			vim.api.nvim_buf_set_lines(0, line, line, false, content)
			vim.api.nvim_win_set_cursor(0, { line + #content, #content[#content] + 1 })
		end
	end

	-- Implement acceptance logic similar to Vim plugin
	if accept_type == "word" then
		-- Word acceptance logic
	elseif accept_type == "line" then
		-- Line acceptance logic
	else -- full
		-- Full completion acceptance logic
	end
end

function M.hide()
	if not M.hint_shown then
		return
	end
	M.hint_shown = false

	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
end

return M
