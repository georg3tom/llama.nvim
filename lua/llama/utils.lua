local config = require("llama.config")

local M = {}

--- @param line number Cursor line position
--- @param col number Cursor column position
function M.get_local_context(line, col)
	local ctx = {
		prefix = "",
		middle = "",
		suffix = "",
		indent = 0,
	}

	local max_lines = vim.fn.line("$")

	local line_cur, line_cur_suffix, lines_prefix, lines_suffix

	line_cur = vim.fn.getline(line)
	ctx.middle = line_cur:sub(1, col)
	line_cur_suffix = line_cur:sub(col + 1)

	lines_prefix = vim.fn.getline(math.max(1, line - config.values.n_prefix), line - 1)

	lines_suffix = vim.fn.getline(line + 1, math.min(max_lines, line + config.values.n_suffix))

	if line_cur:match("^%s*$") then
		ctx.indent = 0
		ctx.middle = ""
		line_cur_suffix = ""
	else
		ctx.indent = #line_cur:match("^%s*")
	end

	ctx.prefix = table.concat(lines_prefix, "\n") .. "\n"
	ctx.suffix = line_cur_suffix .. "\n" .. table.concat(lines_suffix, "\n") .. "\n"

	return ctx
end

--- @param text table Lines of text
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

function M.preprocess_content(content)
	if content == nil or content:match("^%s*$") ~= nil then
		return nil
	end
	-- remove trailing white space
	content = content:gsub("[%s\n]+$", "")
	return content
end

return M
