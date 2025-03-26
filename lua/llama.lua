local config = require("llama.config")
local fim = require("llama.fim")
local utils = require("llama.utils")
local cache = require("llama.cache")

local M = {}

function M.setup(user_config)
	config.update(user_config or {})
	M.create_autocmds()
	M.create_keymaps()
	cache.init()
end

M.timer = nil

function M.debounce_fim_complete()
	if M.timer then
		M.timer:stop()
		M.timer:close()
	end

	M.timer = vim.loop.new_timer()
	M.timer:start(
		100,
		0,
		vim.schedule_wrap(function()
			fim.complete(true, {}, true)
		end)
	)
end

function M.create_autocmds()
	local group = vim.api.nvim_create_augroup("LlamaCompletion", { clear = true })

	if config.values.auto_fim then
		vim.api.nvim_create_autocmd({ "CursorMovedI" }, {
			group = group,
			callback = function()
				if config.values.auto_fim then
					M.debounce_fim_complete()
				end
			end,
		})
	end

	vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
		group = group,
		callback = function(args)
			if args.event == "InsertLeave" then
				fim.hide()
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "TextYankPost", "BufEnter", "BufLeave", "BufWritePost" }, {
		group = group,
		callback = function(args)
			if args.event == "TextYankPost" and vim.v.event.operator == "y" then
				utils.pick_chunk(vim.v.event.regcontents, false, true)
			else
				utils.pick_chunk(
					vim.api.nvim_buf_get_lines(
						0,
						math.max(1, vim.fn.line(".") - config.values.ring_chunk_size / 2),
						math.min(vim.fn.line("$"), vim.fn.line(".") + config.values.ring_chunk_size / 2),
						false
					),
					true,
					true
				)
			end
		end,
	})
end

function M.create_keymaps()
	vim.keymap.set("i", config.values.keymap_trigger, function()
		fim.complete_inline(false, false)
	end, { silent = true, expr = true })

	vim.keymap.set("i", config.values.keymap_accept_full, function()
		fim.accept("full")
	end, { noremap = true, silent = true })

	vim.keymap.set("i", config.values.keymap_accept_line, function()
		fim.accept("line")
	end, { silent = true })

	vim.keymap.set("i", config.values.keymap_accept_word, function()
		fim.accept("word")
	end, { silent = true })
end

function M.create_commands()
	vim.api.nvim_create_user_command("LlamaEnable", M.setup, {})
	vim.api.nvim_create_user_command("LlamaDisable", fim.hide, {})
	vim.api.nvim_create_user_command("LlamaToggle", function()
		-- Toggle logic would be implemented here
	end, {})
end

return M
