local M = {}

M.levels = {
	DEBUG = { name = "DEBUG", color = "Comment", level = 1 },
	INFO = { name = "INFO", color = "Normal", level = 2 },
	WARN = { name = "WARN", color = "WarningMsg", level = 3 },
	ERROR = { name = "ERROR", color = "ErrorMsg", level = 4 },
}

M.current_level = M.levels.INFO.level

M.logs = {}

function M.set_log_level(level_name)
	if M.levels[level_name] then
		M.current_level = M.levels[level_name].level
		return true
	end
	return false
end

function M.log(message, level_name)
	level_name = level_name or "INFO"
	local level = M.levels[level_name] or M.levels.INFO

	if level.level >= M.current_level then
		local timestamp = os.date("%Y-%m-%d %H:%M:%S")
		table.insert(M.logs, {
			timestamp = timestamp,
			message = message,
			level = level,
		})

		if #M.logs > 1000 then
			table.remove(M.logs, 1)
		end
	end
end

function M.debug(message)
	M.log(message, "DEBUG")
end
function M.info(message)
	M.log(message, "INFO")
end
function M.warn(message)
	M.log(message, "WARN")
end
function M.error(message)
	M.log(message, "ERROR")
end

function M.get_logs()
	return M.logs
end

function M.clear_logs()
	M.logs = {}
end

function M.format_log_entry(log_entry)
	return string.format("%s [%s] %s", log_entry.timestamp, log_entry.level.name, log_entry.message)
end

function M.show()
	local buf = vim.api.nvim_create_buf(false, true)

	local logs = M.get_logs()

	local formatted_logs = {}
	if #logs == 0 then
		table.insert(formatted_logs, "No logs available.")
	else
		for _, log_entry in ipairs(logs) do
			local formatted_entry = M.format_log_entry(log_entry)
			for line in formatted_entry:gmatch("[^\r\n]+") do
				table.insert(formatted_logs, line)
			end
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted_logs)

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("filetype", "llamalogs", { buf = buf })

	local width = math.max(120, vim.o.columns - 8)
	local height = math.max(30, vim.o.lines - 6)

	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"c",
		":lua require('llama.logger').clear_logs()<CR><cmd>close<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
