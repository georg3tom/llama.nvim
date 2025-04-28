local config = require("llama.config")
local fim = require("llama.fim")

local M = {}

function M.create_autocmds()
  local group = vim.api.nvim_create_augroup("LlamaCompletion", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMovedI", "CompleteDone" }, {
    group = group,
    callback = function()
      if config.values.auto_fim then
        fim.hide()
        fim.debounce_complete(true)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeavePre" }, {
    group = group,
    callback = function(args)
      if args.event == "InsertEnter" then
        fim.can_show = true
      end
      if args.event == "InsertLeavePre" then
        fim.can_show = false
        fim.hide()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "CompleteChanged" }, {
    group = group,
    callback = function()
      fim.hide()
    end,
  })
end

function M.remove_autocmds()
  vim.api.nvim_clear_autocmds({ group = "LlamaCompletion" })
end

return M
