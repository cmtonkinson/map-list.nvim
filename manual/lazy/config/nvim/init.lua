local repo = assert(os.getenv("MAP_LIST_REPO"), "MAP_LIST_REPO is required")
local common = dofile(repo .. "/manual/common.lua")
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if vim.fn.isdirectory(lazypath) == 0 then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.runtimepath:prepend(lazypath)

common.setup_basics()

require("lazy").setup({
  {
    dir = repo,
    name = "map-list.nvim",
    keys = {
      {
        "<leader>ml",
        "<cmd>Map <lt>leader><CR>",
        desc = "List leader keymaps",
      },
    },
  },
  {
    "FabijanZulj/blame.nvim",
    keys = {
      {
        "<leader>bw",
        "<cmd>BlameToggle window<CR>",
        desc = "Toggle blame window",
      },
      {
        "<leader>bv",
        "<cmd>BlameToggle virtual<CR>",
        desc = "Toggle virtual blame",
      },
    },
  },
  {
    "RRethy/nvim-align",
  },
  "numToStr/Comment.nvim",
  "tpope/vim-fugitive",
  "lewis6991/gitsigns.nvim",
  "folke/tokyonight.nvim",
})

common.apply_colorscheme("tokyonight")
common.setup_plugin_keymaps()
