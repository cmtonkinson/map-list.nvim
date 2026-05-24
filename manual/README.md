# Manual Test Harness
These profiles launch isolated Neovim instances for manual plugin-manager
testing. Each profile uses its own XDG config, data, state, and cache
directories under `manual/`.

From the repository root:
```sh
./manual/lazy/start
./manual/vim-plug/start
./manual/packer/start
```

Each launcher installs or syncs these plugins through that profile's plugin
manager before opening Neovim:
- local `map-list.nvim` from this checkout
- `FabijanZulj/blame.nvim`
- `RRethy/nvim-align`
- `numToStr/Comment.nvim`
- `tpope/vim-fugitive`
- `lewis6991/gitsigns.nvim`

Each profile also installs one colorscheme:
- lazy.nvim: `folke/tokyonight.nvim`
- vim-plug: `rebelot/kanagawa.nvim`
- packer.nvim: `EdenEast/nightfox.nvim`

Each profile also sets these built-in mappings:
- `<leader>e` to `vim.diagnostic.open_float`
- `<leader>h` to `:nohlsearch`
- `<leader>q` to `vim.diagnostic.setloclist`

Each profile maps the same plugin commands:
- `<leader>ml` to `:Map <leader>`
- `<leader>a` in visual mode to `:Align =`
- `<leader>bb` to `:BlameToggle`
- `<leader>bv` to `:BlameToggle virtual`
- `<leader>bw` to `:BlameToggle window`
- `<leader>cc` to toggle the current line comment
- `<leader>cb` to toggle the current block comment
- `<leader>cl` in visual mode to toggle selected line comments
- `<leader>fc` to `:Git commit`
- `<leader>fd` to `:Gdiffsplit`
- `<leader>fs` to `:Git status`
- `<leader>gb` to `:Gitsigns blame_line`
- `<leader>gd` to `:Gitsigns diffthis`
- `<leader>gp` to `:Gitsigns preview_hunk`
