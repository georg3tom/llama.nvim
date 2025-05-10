local M = {}

M.values = {
  endpoint = "127.0.0.1:8012/infill",
  api_key = "",
  n_prefix = 256,
  n_suffix = 64,
  n_predict = 128,
  stop_strings = {},
  t_max_prompt_ms = 500,
  t_max_predict_ms = 1000,
  show_info = 2,
  auto_fim = true,
  max_line_suffix = 8,
  max_cache_keys = 250,
  ring_n_chunks = 16,
  ring_chunk_size = 64,
  ring_scope = 1024,
  ring_update_ms = 1000,
  keymap_trigger = "<C-F>",
  keymap_accept_full = "<Tab>",
  keymap_accept_line = "<S-Tab>",
  keymap_accept_word = "<C-B>",
}

--- @param user_config table
function M.update(user_config)
  M.values = vim.tbl_deep_extend("force", M.values, user_config or {})
end

return M
