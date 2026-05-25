vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/.deps/mini.nvim")

require("mini.test").setup({
  collect = {
    find_files = function()
      return {
        "tests/test-map-list.lua",
        "tests/test-source-providers.lua",
        "tests/test-regressions.lua",
      }
    end,
  },
})
