local config = require("llama.config")
local fim = require("llama.fim")
local cache = require("llama.cache")
local autocmd = require("llama.autocmd")

local M = {}

function M.setup(user_config)
	config.update(user_config or {})
	autocmd.create_autocmds()
	-- fim.create_keymaps()
	cache.init()
end

function M.create_commands()
	vim.api.nvim_create_user_command("LlamaEnable", M.setup, {})
	vim.api.nvim_create_user_command("LlamaDisable", fim.hide, {})
	vim.api.nvim_create_user_command("LlamaToggle", function()
		-- Toggle logic would be implemented here
	end, {})
end

return M
