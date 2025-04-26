local config = require("llama.config")
local fim = require("llama.fim")
local utils = require("llama.utils")

local M = {}

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
      fim.complete(true)
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
          fim.hide()
          require("llama.autocmd").debounce_fim_complete()
        end
      end,
    })
  end

  vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
    group = group,
    callback = function(args)
      if args.event == "InsertEnter" then
        fim.can_show = true
      end
      if args.event == "InsertLeave" then
        fim.can_show = false
        fim.hide()
      end
    end,
  })

  vim.api.nvim_create_autocmd(
    { "TextYankPost", "BufEnter", "BufLeave", "BufWritePost" },
    {
      group = group,
      callback = function(args)
        if args.event == "TextYankPost" and vim.v.event.operator == "y" then
          utils.pick_chunk(vim.v.event.regcontents, false, true)
        else
          utils.pick_chunk(
            vim.api.nvim_buf_get_lines(
              0,
              math.max(1, vim.fn.line(".") - config.values.ring_chunk_size / 2),
              math.min(
                vim.fn.line("$"),
                vim.fn.line(".") + config.values.ring_chunk_size / 2
              ),
              false
            ),
            true,
            true
          )
        end
      end,
    }
  )
end

function M.remove_autocmds()
  vim.api.nvim_clear_autocmds({ group = "LlamaCompletion" })
end

return M
