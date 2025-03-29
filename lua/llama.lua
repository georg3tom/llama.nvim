local config = require("llama.config")
local fim = require("llama.fim")
local autocmd = require("llama.autocmd")

local M = {}

function M.setup(user_config)
	config.update(user_config or {})
	autocmd.create_autocmds()
	M.remove_existing_mappings()
end

function M.create_commands()
	vim.api.nvim_create_user_command("LlamaEnable", M.setup, {})
	vim.api.nvim_create_user_command("LlamaDisable", fim.hide, {})
	vim.api.nvim_create_user_command("LlamaToggle", function()
		-- Toggle logic would be implemented here
	end, {})
end

-- TODO: this is evil. figure out something else
function M.remove_existing_mappings()
	pcall(vim.api.nvim_buf_del_keymap, 0, "i", config.values.keymap_trigger)
	pcall(vim.api.nvim_buf_del_keymap, 0, "i", config.values.keymap_accept_full)
	pcall(vim.api.nvim_buf_del_keymap, 0, "i", config.values.keymap_accept_line)
	pcall(vim.api.nvim_buf_del_keymap, 0, "i", config.values.keymap_accept_word)
	pcall(vim.api.nvim_del_keymap, "i", config.values.keymap_trigger)
	pcall(vim.api.nvim_del_keymap, "i", config.values.keymap_accept_full)
	pcall(vim.api.nvim_del_keymap, "i", config.values.keymap_accept_line)
	pcall(vim.api.nvim_del_keymap, "i", config.values.keymap_accept_word)
end

return M
