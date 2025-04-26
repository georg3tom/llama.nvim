local config = require("llama.config")

local M = {}
function M.create_keymaps()
  vim.keymap.set("i", config.values.keymap_trigger, function()
    require("llama.fim").complete(false)
  end, { silent = false, expr = true, desc = "llama.nvim inline completion" })

  vim.keymap.set("i", config.values.keymap_accept_full, function()
    require("llama.fim").accept("full")
  end, { noremap = false, silent = true, desc = "llama.nvim accept completion" })

  vim.keymap.set("i", config.values.keymap_accept_line, function()
    require("llama.fim").accept("line")
  end, { noremap = false, silent = true, desc = "llama.nvim accept line completion" })

  vim.keymap.set("i", config.values.keymap_accept_word, function()
    require("llama.fim").accept("word")
  end, { noremap = false, silent = true, desc = "llama.nvim accept word completion" })
end

function M.remove_keymaps()
  vim.keymap.del("i", config.values.keymap_trigger, { silent = true })
  vim.keymap.del("i", config.values.keymap_accept_full, { silent = true })
  vim.keymap.del("i", config.values.keymap_accept_line, { silent = true })
  vim.keymap.del("i", config.values.keymap_accept_word, { silent = true })
end

return M
