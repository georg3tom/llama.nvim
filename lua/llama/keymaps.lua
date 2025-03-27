local config = require("llama.config")

M = {}
function M.create_keymaps()
	print("keymap created")
	vim.keymap.set("i", config.values.keymap_trigger, function()
		require("llama.fim").complete_inline(false, false)
	end, { silent = true, expr = true })

	vim.keymap.set("i", config.values.keymap_accept_full, function()
		require("llama.fim").accept("full")
	end, { noremap = true, silent = true })

	vim.keymap.set("i", config.values.keymap_accept_line, function()
		require("llama.fim").accept("line")
	end, { noremap = true, silent = true })

	vim.keymap.set("i", config.values.keymap_accept_word, function()
		require("llama.fim").accept("word")
	end, { noremap = true, silent = true })
end

function M.remove_keymaps()
	print("keymap removed")
	vim.keymap.del("i", config.values.keymap_trigger, { buffer = true, silent = true })
	vim.keymap.del("i", config.values.keymap_accept_full, { buffer = true, silent = true })
	vim.keymap.del("i", config.values.keymap_accept_line, { buffer = true, silent = true })
	vim.keymap.del("i", config.values.keymap_accept_word, { buffer = true, silent = true })
end

return M
