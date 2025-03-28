# Llama.nvim

[wip] Lua rewrite of [ggml-org/llama.vim](https://github.com/ggml-org/llama.vim)


## Prerequisites

- Neovim 0.9+
- A running local LLM server (e.g., llama.cpp) check [here](https://github.com/ggml-org/llama.vim?tab=readme-ov-file#llamacpp-setup)

## Installation

Lazy.nvim setup

```lua
{
    'georg3tom/llama.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
        require('llama').setup({
            -- Your configuration options here
            endpoint = 'http://localhost:8012/infill',
            auto_fim = true,
            n_predict = 128
        })
    end
}
```

## Configuration

```lua
require('llama').setup({
    endpoint = 'http://127.0.0.1:8012/infill',  -- LLM server endpoint
    api_key = '',                               -- Optional API key
    n_prefix = 256,                             -- Lines of context before cursor
    n_suffix = 64,                              -- Lines of context after cursor
    n_predict = 128,                            -- Maximum tokens to predict
    auto_fim = true,                            -- Auto-trigger completion
    keymap_trigger = '<C-F>',                   -- Trigger completion keymap
    keymap_accept_full = '<Tab>',               -- Accept full completion
    keymap_accept_line = '<S-Tab>',             -- Accept line completion
    keymap_accept_word = '<C-B>'                -- Accept word completion
})
```

## Usage

- `<C-F>`: Trigger completion
- `<Tab>`: Accept full completion
<!-- - `<S-Tab>`: Accept line completion
- `<C-B>`: Accept word completion -->

### Commands

- `:LlamaEnable`: Enable the plugin
- `:LlamaDisable`: Disable the plugin
- `:LlamaToggle`: Toggle the plugin
