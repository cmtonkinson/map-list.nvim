local repo = assert(os.getenv("MAP_LIST_REPO"), "MAP_LIST_REPO is required")
local common = dofile(repo .. "/manual/common.lua")
local package_root = vim.fn.stdpath("data") .. "/site/pack"
local compile_path = vim.fn.stdpath("config") .. "/plugin/packer_compiled.lua"
local start_root = package_root .. "/packer/start"
local packer_path = vim.fn.stdpath("data")
  .. "/site/pack/packer/start/packer.nvim"

if vim.fn.isdirectory(packer_path) == 0 then
  vim.fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    packer_path,
  })
end

vim.opt.runtimepath:prepend(packer_path)
vim.opt.packpath:prepend(vim.fn.stdpath("data") .. "/site")

common.setup_basics()

local packer = require("packer")

packer.init({
  package_root = package_root,
  compile_path = compile_path,
})

packer.startup(function(use)
  use("wbthomason/packer.nvim")
  use(repo)
  use("FabijanZulj/blame.nvim")
  use("RRethy/nvim-align")
  use("numToStr/Comment.nvim")
  use("tpope/vim-fugitive")
  use("lewis6991/gitsigns.nvim")
  use("EdenEast/nightfox.nvim")
end)

for _, plugin in ipairs({
  "nightfox.nvim",
  "nvim-align",
  "blame.nvim",
  "Comment.nvim",
  "vim-fugitive",
  "gitsigns.nvim",
}) do
  local path = start_root .. "/" .. plugin
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:prepend(path)
  end
end

vim.opt.runtimepath:prepend(repo)
vim.cmd.runtime("plugin/map-list.lua")
vim.cmd.runtime("plugin/align.vim")
vim.cmd.runtime("plugin/comment.lua")
vim.cmd.runtime("plugin/fugitive.vim")
if vim.fn.filereadable(compile_path) == 1 then
  pcall(dofile, compile_path)
end
common.apply_colorscheme("nightfox")
common.setup_plugin_keymaps()

if os.getenv("MANUAL_PACKER_SYNC") == "1" then
  require("packer.plugin_utils").update_rplugins = function() end

  vim.api.nvim_create_autocmd("User", {
    pattern = "PackerComplete",
    callback = function()
      vim.cmd.quitall()
    end,
  })

  packer.sync()
end
