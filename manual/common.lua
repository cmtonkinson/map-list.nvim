local M = {}

function M.apply_colorscheme(name)
  pcall(vim.cmd.colorscheme, name)
end

function M.setup_basics()
  vim.g.mapleader = " "
  vim.g.maplocalleader = " "

  vim.diagnostic.config({
    severity_sort = true,
    virtual_text = true,
    underline = true,
    update_in_insert = false,
    float = {
      border = "rounded",
      source = "if_many",
    },
  })

  vim.keymap.set(
    "n",
    "<leader>e",
    vim.diagnostic.open_float,
    { desc = "Line diagnostics" }
  )
  vim.keymap.set("n", "<leader>h", "<cmd>nohlsearch<CR>", {
    desc = "Clear search highlight",
    silent = true,
  })
  vim.keymap.set(
    "n",
    "<leader>q",
    vim.diagnostic.setloclist,
    { desc = "Diagnostics to loclist" }
  )
end

function M.setup_plugin_keymaps()
  pcall(function()
    require("blame").setup({})
  end)
  pcall(function()
    require("Comment").setup({})
  end)
  pcall(function()
    require("gitsigns").setup({})
  end)

  local function setup_map_list()
    require("map-list").setup()
  end

  pcall(setup_map_list)
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      pcall(setup_map_list)
    end,
  })

  vim.keymap.set("n", "<leader>ml", "<cmd>Map <lt>leader><CR>", {
    desc = "List leader keymaps",
  })
  vim.keymap.set("x", "<leader>a", ":Align =<CR>", {
    desc = "Align selection on equals",
  })

  vim.keymap.set("n", "<leader>bb", "<cmd>BlameToggle<CR>", {
    desc = "Toggle blame",
  })
  vim.keymap.set("n", "<leader>bv", "<cmd>BlameToggle virtual<CR>", {
    desc = "Toggle virtual blame",
  })
  vim.keymap.set("n", "<leader>bw", "<cmd>BlameToggle window<CR>", {
    desc = "Toggle blame window",
  })

  vim.keymap.set("n", "<leader>cc", "<Plug>(comment_toggle_linewise_current)", {
    desc = "Toggle line comment",
  })
  vim.keymap.set(
    "n",
    "<leader>cb",
    "<Plug>(comment_toggle_blockwise_current)",
    {
      desc = "Toggle block comment",
    }
  )
  vim.keymap.set("x", "<leader>cl", "<Plug>(comment_toggle_linewise_visual)", {
    desc = "Toggle selection comment",
  })

  vim.keymap.set("n", "<leader>fc", "<cmd>Git commit<CR>", {
    desc = "Git commit",
  })
  vim.keymap.set("n", "<leader>fd", "<cmd>Gdiffsplit<CR>", {
    desc = "Git diff split",
  })
  vim.keymap.set("n", "<leader>fs", "<cmd>Git status<CR>", {
    desc = "Git status",
  })

  vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns blame_line<CR>", {
    desc = "Blame current line",
  })
  vim.keymap.set("n", "<leader>gd", "<cmd>Gitsigns diffthis<CR>", {
    desc = "Diff this buffer",
  })
  vim.keymap.set("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", {
    desc = "Preview git hunk",
  })
end

return M
