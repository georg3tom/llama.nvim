# llama.nvim

A Neovim plugin that provides local LLM-powered code completion. This is a Lua rewrite of [ggml-org/llama.vim](https://github.com/ggml-org/llama.vim).

## Prerequisites

- Neovim 0.9+
- A running local LLM server (e.g., llama.cpp) check [here](https://github.com/ggml-org/llama.vim?tab=readme-ov-file#llamacpp-setup)

## Features

- [x] LRU caching of requests
- [ ] Treesitter based extra context
- [ ] Play nicely with blink.cmp and other plugins
- [ ] Profiling

## Installation

### Lazy.nvim

```lua
{
    'georg3tom/llama.nvim',
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

### Packer

```lua
use {
    'georg3tom/llama.nvim',
    config = function()
        require('llama').setup({
            -- Your configuration options here
        })
    end
}
```

## Configuration

The plugin can be configured with the following options:

```lua
require('llama').setup({
    endpoint = '127.0.0.1:8012/infill',  -- LLM server endpoint
    api_key = '',                               -- Optional API key
    n_prefix = 256,                             -- Lines of context before cursor
    n_suffix = 64,                              -- Lines of context after cursor
    n_predict = 128,                            -- Maximum tokens to predict
    stop_strings = {},                          -- Strings that stop generation when encountered
    auto_fim = true,                            -- Auto-trigger completion
    max_cache_keys = 250,                       -- Size of the cache
    keymap_trigger = '<C-F>',                   -- Trigger completion keymap
    keymap_accept_full = '<Tab>',               -- Accept full completion
    keymap_accept_line = '<S-Tab>',             -- Accept line completion
    keymap_accept_word = '<C-B>'                -- Accept word completion
})
```

### Example: Force Single-Line Completions

To force completions to be single-line only, configure the `stop_strings` option to include a newline character:

```lua
require('llama').setup({
    -- Other configuration options
    stop_strings = { "\n" },
})
```

## Usage

### Keymaps

- `<C-F>`: Trigger completion manually
- `<Tab>`: Accept the full completion
- `<S-Tab>`: Accept line completion
- `<C-B>`: Accept word completion

### Commands

- `:LlamaEnable`: Enable the plugin
- `:LlamaDisable`: Disable the plugin
- `:LlamaToggle`: Toggle the plugin
- `:LlamaInfo`: Show logs
