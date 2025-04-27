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

  lines_suffix =
    vim.fn.getline(line + 1, math.min(max_lines, line + config.values.n_suffix))

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

function M.preprocess_content(content)
  if content == nil or content:match("^%s*$") ~= nil then
    return nil
  end
  -- remove trailing white space
  content = content:gsub("[%s\n]+$", "")
  return content
end

return M
