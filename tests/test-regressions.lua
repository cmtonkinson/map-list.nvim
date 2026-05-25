local helpers = require("tests.helpers")
local child = helpers.child
local map_lines = helpers.map_lines
local contains = helpers.contains
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

--[[
Issue #1: LazyVim/lazy.nvim plugin specs can provide `keys` as a function.
The lazy source provider treated `plugin.keys` as an already-materialized list
and passed the function directly to `ipairs`, making `:Map` fail before any
keymaps could be rendered.
]]
T["issue #1 lazy provider builds context from function keys"] = function()
  local result = child.lua([[
    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          issue_one = {
            name = "issue-one.nvim",
            keys = function()
              return {
                { "maplistissueone", mode = "n" },
              }
            end,
          },
        },
      }
    end

    local context = require("map-list.source-providers.lazy").context()

    return context.keys["n\0maplistissueone"]
  ]])

  eq(result, "issue-one.nvim")
end

T["issue #1 Map renders mappings from function keys"] = function()
  child.lua([[
    vim.o.columns = 120

    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          issue_one = {
            name = "issue-one.nvim",
            keys = function()
              return {
                { "maplistissueone", mode = "n" },
              }
            end,
          },
        },
      }
    end

    vim.keymap.set("n", "maplistissueone", function() end, {
      desc = "Map List Issue One",
    })
  ]])

  local line = contains(map_lines("Map maplistissueone"), "Map List Issue One")

  contains({ line }, "issue-one.nvim")
end

return T
