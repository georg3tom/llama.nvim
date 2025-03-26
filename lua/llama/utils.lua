local config = require("llama.config")

local M = {}


--- @param line number Cursor line position
--- @param col number Cursor column position
--- @param prev table Previous completion context
--- @return table Local context information
function M.get_local_context(line, col, prev)
	local ctx = {
		prefix = "",
		middle = "",
		suffix = "",
		indent = 0,
	}

	local max_lines = vim.fn.line("$")

	local line_cur, line_cur_prefix, line_cur_suffix, lines_prefix, lines_suffix, indent

	if #prev == 0 then
		line_cur = vim.fn.getline(line)
		line_cur_prefix = line_cur:sub(1, col)
		line_cur_suffix = line_cur:sub(col + 1)

		lines_prefix = vim.fn.getline(math.max(1, line - config.values.n_prefix), line - 1)

		lines_suffix = vim.fn.getline(line + 1, math.min(max_lines, line + config.values.n_suffix))

		if line_cur:match("^%s*$") then
			indent = 0
			line_cur_prefix = ""
			line_cur_suffix = ""
		else
			indent = #line_cur:match("^%s*")
		end
	else
		-- Handling previous context
		-- if #prev == 1 then
		-- 	line_cur = vim.fn.getline(line) .. prev[1]
		-- else
		-- 	line_cur = prev[#prev]
		-- end
		--
		-- line_cur_prefix = line_cur
		-- line_cur_suffix = ""
		--
		-- -- Get prefix lines with previous context
		-- lines_prefix = vim.fn.getline(math.max(1, line - config.values.n_prefix + #prev - 1), line - 1)
		--
		-- if #prev > 1 then
		-- 	table.insert(lines_prefix, vim.fn.getline(line) .. prev[1])
		-- 	for i = 2, #prev - 1 do
		-- 		table.insert(lines_prefix, prev[i])
		-- 	end
		-- end
		--
		-- -- Get suffix lines
		-- lines_suffix = vim.fn.getline(line + 1, math.min(max_lines, line + config.values.n_suffix))
		--
		-- indent = s_indent_last -- Note: This assumes s_indent_last is defined elsewhere
	end

	ctx.prefix = table.concat(lines_prefix, "\n") .. "\n"
	ctx.middle = line_cur_prefix
	ctx.suffix = line_cur_suffix .. "\n" .. table.concat(lines_suffix, "\n") .. "\n"

	return ctx
end

--- @param text table Lines of text
--- @param no_mod boolean Avoid picking from modified buffers
--- @param do_evict boolean Evict similar chunks
function M.pick_chunk(text, no_mod, do_evict)
	-- Similar implementation to Vim plugin's pick_chunk function
	-- Handles chunk selection, caching, and context management
end

--- Compute chunk similarity
--- @param c0 table First chunk of text
--- @param c1 table Second chunk of text
--- @return number Similarity score (0-1)
function M.chunk_similarity(c0, c1)
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

return M
