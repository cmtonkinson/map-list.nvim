local repo = assert(os.getenv("MAP_LIST_REPO"), "MAP_LIST_REPO is required")
local common = dofile(repo .. "/manual/common.lua")
local plug = vim.fn.stdpath("data") .. "/site/autoload/plug.vim"

if vim.fn.filereadable(plug) == 0 then
  vim.fn.system({
    "curl",
    "-fLo",
    plug,
    "--create-dirs",
    "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim",
  })
end

vim.cmd.source(vim.fn.fnameescape(plug))
vim.opt.runtimepath:prepend(repo)
require("map-list.source-location").enable_tracking()

common.setup_basics()

vim.fn["plug#begin"](vim.fn.stdpath("data") .. "/plugged")
vim.cmd("Plug " .. vim.fn.string(repo))
vim.cmd("Plug 'nvim-lua/plenary.nvim'")
vim.cmd("Plug 'nvim-telescope/telescope.nvim'")
vim.cmd("Plug 'FabijanZulj/blame.nvim'")
vim.cmd("Plug 'RRethy/nvim-align'")
vim.cmd("Plug 'numToStr/Comment.nvim'")
vim.cmd("Plug 'tpope/vim-fugitive'")
vim.cmd("Plug 'lewis6991/gitsigns.nvim'")
vim.cmd("Plug 'rebelot/kanagawa.nvim'")
vim.g.loaded_map_list = 1
vim.fn["plug#end"]()

common.apply_colorscheme("kanagawa")
common.setup_plugin_keymaps()
