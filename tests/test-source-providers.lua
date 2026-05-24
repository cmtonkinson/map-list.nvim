local helpers = require("tests.helpers")
local child = helpers.child
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "tests/minimal-init.lua" })
      child.lua([[
        vim.g.mapleader = " "
        vim.g.maplocalleader = ","
        require("map-list").setup()
      ]])
    end,
    post_once = child.stop,
  },
})

local function map_lines(command)
  return child.lua(
    [[
    local command = ...

    vim.cmd(command)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    if vim.bo.buftype == "nofile" then
      vim.cmd("bwipeout!")
    end

    return lines
  ]],
    { command }
  )
end

local function contains(lines, needle)
  for _, line in ipairs(lines) do
    if line:find(needle, 1, true) ~= nil then
      return line
    end
  end

  error(
    ("expected lines to contain %s\n%s"):format(
      vim.inspect(needle),
      table.concat(lines, "\n")
    )
  )
end

local function rejects(lines, needle)
  for _, line in ipairs(lines) do
    if line:find(needle, 1, true) ~= nil then
      error(
        ("expected lines not to contain %s\n%s"):format(
          vim.inspect(needle),
          table.concat(lines, "\n")
        )
      )
    end
  end
end

local function expect_match(value, pattern)
  if value:match(pattern) == nil then
    error(
      ("expected %s to match %s"):format(
        vim.inspect(value),
        vim.inspect(pattern)
      ),
      2
    )
  end
end

T["lazy provider attributes matching key specs to plugins"] = function()
  child.lua([[
    vim.o.columns = 120

    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          fallback = {
            keys = {
              { "<leader>maplistlazyfallback" },
            },
          },
          named = {
            name = "named-plugin.nvim",
            keys = {
              { "<leader>maplistlazy", mode = "n" },
              { "<Space>maplistlazyspace", mode = "n" },
            },
          },
          visual = {
            name = "visual-plugin.nvim",
            keys = {
              { "maplistlazyvisual", mode = "x" },
            },
          },
        },
      }
    end

    vim.keymap.set("n", "<leader>maplistlazy", function() end, {
      desc = "Map List Test Lazy",
    })
    vim.keymap.set("n", "<Space>maplistlazyspace", function() end, {
      desc = "Map List Test Lazy Space",
    })
    vim.keymap.set("n", "<leader>maplistlazyfallback", function() end, {
      desc = "Map List Test Lazy Fallback",
    })
    vim.keymap.set("x", "maplistlazyvisual", function() end, {
      desc = "Map List Test Lazy Visual",
    })
  ]])

  local lines = map_lines("Map maplistlazy")

  contains(lines, "named-plugin.nvim")
  contains(lines, "visual-plugin.nvim")
  contains(lines, "fallback")
end

T["source providers use fixed package callback rhs order"] = function()
  child.lua([[
    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          fixed = {
            name = "fixed-source.nvim",
            keys = {
              { "maplistfixedsource", mode = "n" },
            },
          },
        },
      }
    end

    vim.keymap.set("n", "maplistfixedsource", function() end, {
      desc = "Map List Test Fixed Source",
    })
  ]])

  local line =
    contains(map_lines("Map maplistfixedsource"), "Map List Test Fixed Source")
  contains({ line }, "fixed-source.nvim")
  rejects({ line }, "[string")

  child.lua([[
    vim.keymap.set("n", "maplistrhsonly", "<Cmd>echo 'x'<CR>", {
      desc = "Map List Test RHS Only",
    })
  ]])

  local rhs_line =
    contains(map_lines("Map maplistrhsonly"), "Map List Test RHS Only")
  contains({ rhs_line }, "<Cmd>echo 'x'<CR>")
end

T["rhs provider returns command rhs text"] = function()
  local result = child.lua([[
    local source, kind = require("map-list.source-providers.rhs").resolve({
      rhs = "<Cmd>echo 'x'<CR>",
    })

    return { source, kind }
  ]])

  eq(result, { "<Cmd>echo 'x'<CR>", "rhs" })
end

T["callback provider returns source references"] = function()
  local result = child.lua([[
    local function callback_fixture() end
    local source, kind = require("map-list.source-providers.callback").resolve({
      callback = callback_fixture,
    })

    return { source, kind }
  ]])

  expect_match(result[1], "%[string")
  eq(result[2], "callback")
end

T["lazy provider is inert when lazy.nvim is unavailable"] = function()
  local result = child.lua([[
    local lazy = require("map-list.source-providers.lazy")
    local context = lazy.context()
    local source = lazy.resolve({ lhs = "x" }, "n", context)

    return { vim.tbl_isempty(context), source }
  ]])

  eq(result, { true })
end

T["source registry resolves callback then rhs fallbacks"] = function()
  local result = child.lua([[
    local registry = require("map-list.source-registry")
    local context = registry.context()

    local function callback_fixture() end
    local callback_source, callback_kind = registry.resolve({
      callback = callback_fixture,
      rhs = "<Cmd>echo 'callback'<CR>",
    }, "n", context)

    local rhs_source, rhs_kind = registry.resolve({
      rhs = "<Cmd>echo 'registry'<CR>",
    }, "n", context)

    return {
      callback_source,
      callback_kind,
      rhs_source,
      rhs_kind,
    }
  ]])

  expect_match(result[1], "%[string")
  eq(result[2], "callback")
  eq(result[3], "<Cmd>echo 'registry'<CR>")
  eq(result[4], "rhs")
end

T["source registry builds provider-specific context"] = function()
  local result = child.lua([[
    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          registry = {
            name = "registry.nvim",
            keys = {
              { "maplistregistrycontext", mode = "n" },
            },
          },
        },
      }
    end

    local context = require("map-list.source-registry").context()

    return {
      context.lazy.keys["n\0maplistregistrycontext"],
      type(context["vim-plug"]) == "table",
      type(context.packer) == "table",
    }
  ]])

  eq(result, { "registry.nvim", true, true })
end

T["vim-plug provider attributes command and callback maps to plugins"] = function()
  local result = child.lua([[
    local root = vim.fn.tempname()
    local plugin_dir = root .. "/plugged/fake.nvim"
    vim.fn.mkdir(plugin_dir .. "/plugin", "p")
    vim.fn.mkdir(plugin_dir .. "/lua", "p")
    vim.fn.writefile({
      'vim.api.nvim_create_user_command("FakeLua", function() end, {})',
      'vim.keymap.set("n", "<Plug>(fake-action)", function() end)',
    }, plugin_dir .. "/plugin/fake.lua")
    vim.fn.writefile({
      "local M = {}",
      "function M.action() end",
      "return M",
    }, plugin_dir .. "/lua/fake_callback.lua")

    vim.g.plugs = {
      ["fake.nvim"] = {
        dir = plugin_dir,
      },
    }

    local provider = require("map-list.source-providers.vim-plug")
    local context = provider.context()
    package.path = plugin_dir .. "/lua/?.lua;" .. package.path

    local command_source, command_kind = provider.resolve({
      rhs = "<Cmd>FakeLua<CR>",
    }, "n", context)
    local plug_source, plug_kind = provider.resolve({
      rhs = "<Plug>(fake-action)",
    }, "n", context)
    local callback_source, callback_kind = provider.resolve({
      callback = require("fake_callback").action,
    }, "n", context)

    return {
      command_source,
      command_kind,
      plug_source,
      plug_kind,
      callback_source,
      callback_kind,
    }
  ]])

  eq(result, {
    "fake.nvim",
    "plugin",
    "fake.nvim",
    "plugin",
    "fake.nvim",
    "plugin",
  })
end

T["packer provider attributes command maps to plugins"] = function()
  local result = child.lua([[
    local root = vim.fn.tempname()
    local plugin_dir = root .. "/site/pack/packer/start/fake-packer.nvim"
    vim.fn.mkdir(plugin_dir .. "/plugin", "p")
    vim.fn.writefile({
      "command! FakePacker echo 'packer'",
    }, plugin_dir .. "/plugin/fake.vim")

    _G.packer_plugins = {
      ["fake-packer.nvim"] = {
        path = plugin_dir,
      },
    }

    local provider = require("map-list.source-providers.packer")
    local context = provider.context()
    local source, kind = provider.resolve({
      rhs = "<Cmd>FakePacker<CR>",
    }, "n", context)

    return { source, kind }
  ]])

  eq(result, { "fake-packer.nvim", "plugin" })
end

return T
