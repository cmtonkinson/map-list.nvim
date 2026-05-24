local helpers = require("tests.helpers")
local child = helpers.child
local eq = MiniTest.expect.equality
local no_error = MiniTest.expect.no_error

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

local function line_index(lines, needle)
  for index, line in ipairs(lines) do
    if line:find(needle, 1, true) ~= nil then
      return index
    end
  end

  error(
    ("expected lines to contain %s\n%s"):format(
      vim.inspect(needle),
      table.concat(lines, "\n")
    )
  )
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

T["registers the default command"] = function()
  eq(child.fn.exists(":Map"), 2)
end

T["can rename the command"] = function()
  child.lua([[require("map-list").setup({ command = "Keymaps" })]])

  eq(child.fn.exists(":Keymaps"), 2)
  eq(child.fn.exists(":Map"), 0)
end

T["filters literal leader mappings"] = function()
  child.lua([[
    vim.keymap.set("n", "<leader>maplisttest", function() end, {
      desc = "Map List Test Leader",
    })
    vim.keymap.set("n", "maplisttest", function() end, {
      desc = "Map List Test Plain",
    })
  ]])

  local lines = map_lines("Map <leader>")

  contains(lines, "<leader>maplisttest")

  for _, line in ipairs(lines) do
    if
      line:find("maplisttest", 1, true) ~= nil
      and line:find("<leader>maplisttest", 1, true) == nil
    then
      error("non-leader mapping matched leader filter: " .. line)
    end
  end
end

T["filters localleader space description rhs and case paths"] = function()
  child.lua([[
    vim.keymap.set("n", "<localleader>maplistlocal", function() end, {
      desc = "Map List Test Localleader",
    })
    vim.keymap.set("n", "<Space>maplistspace", function() end, {
      desc = "Map List Test Space",
    })
    vim.keymap.set("n", "maplistdesc", function() end, {
      desc = "Map List Test Rename Case",
    })
    vim.keymap.set("n", "maplistrhs", "<Cmd>MapListRhsNeedle<CR>", {
      desc = "Map List Test RHS",
    })
    vim.keymap.set("n", "maplistplain", function() end, {
      desc = "Map List Test Plain",
    })
  ]])

  local localleader_lines = map_lines("Map <localleader>")
  contains(localleader_lines, "<localleader>maplistlocal")
  rejects(localleader_lines, "maplistplain")

  local space_lines = map_lines("Map <Space>maplistspace")
  contains(space_lines, "<leader>maplistspace")
  rejects(space_lines, "maplistplain")

  local desc_lines = map_lines("Map rename")
  contains(desc_lines, "Map List Test Rename Case")
  rejects(desc_lines, "Map List Test Plain")

  local rhs_lines = map_lines("Map rhsneedle")
  contains(rhs_lines, "Map List Test RHS")
  rejects(rhs_lines, "Map List Test Plain")

  local case_lines = map_lines("Map RENAMe")
  contains(case_lines, "Map List Test Rename Case")

  local spaced_filter_lines = map_lines("Map <Space>missing")
  rejects(spaced_filter_lines, "Map List Test Rename Case")
  rejects(spaced_filter_lines, "Map List Test RHS")
end

T["marks buffer-local mappings with at-sign mode suffix"] = function()
  child.lua([[
    vim.keymap.set("n", "maplistglobal", function() end, {
      desc = "Map List Test Global",
    })
    vim.keymap.set("n", "maplistbuffer", function() end, {
      buffer = true,
      desc = "Map List Test Buffer",
    })
  ]])

  local lines = map_lines("Map maplist")
  expect_match(contains(lines, "Map List Test Global"), "^n%s+")
  expect_match(contains(lines, "Map List Test Buffer"), "^n@%s+")
end

T["sorts lhs case-insensitively with lowercase first"] = function()
  child.lua([[
    vim.keymap.set("n", "maplistcasea", function() end, {
      desc = "Map List Test Sort Lower",
    })
    vim.keymap.set("n", "maplistcaseA", function() end, {
      desc = "Map List Test Sort Upper",
    })
    vim.keymap.set("n", "maplistcaseb", function() end, {
      desc = "Map List Test Sort Later",
    })
  ]])

  local lines = map_lines("Map maplistcase")

  eq(
    line_index(lines, "Map List Test Sort Lower")
      < line_index(lines, "Map List Test Sort Upper"),
    true
  )
  eq(
    line_index(lines, "Map List Test Sort Upper")
      < line_index(lines, "Map List Test Sort Later"),
    true
  )
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

T["source provider order and removal are configurable"] = function()
  child.lua([[
    require("map-list").setup({
      source_providers = {
        function()
          return "custom-source.nvim", "plugin"
        end,
        "rhs",
      },
    })

    vim.keymap.set("n", "maplistcustomsource", "<Cmd>echo 'x'<CR>", {
      desc = "Map List Test Custom Source",
    })
  ]])

  contains(map_lines("Map maplistcustomsource"), "custom-source.nvim")

  child.lua([[
    require("map-list").setup({
      source_providers = { "rhs" },
    })

    vim.keymap.set("n", "maplistrhsonly", function() end, {
      desc = "Map List Test RHS Only",
    })
  ]])

  local line =
    contains(map_lines("Map maplistrhsonly"), "Map List Test RHS Only")
  contains({ line }, "<Lua function>")
  rejects({ line }, "[string")
end

T["renders callback sources as file and line references"] = function()
  child.lua([[
    vim.keymap.set("n", "<leader>maplistsource", function() end, {
      desc = "Map List Test Source",
    })
  ]])

  local lines = map_lines("Map <leader>maplistsource")
  local line = contains(lines, "Map List Test Source")

  expect_match(line, "%[string")
end

T["marks leader text and callback sources with Comment highlights"] = function()
  child.lua([[
    vim.keymap.set("n", "<leader>maplisthl", function() end, {
      desc = "Map List Test Highlights",
    })

    vim.cmd("Map <leader>maplisthl")
  ]])

  local comment_marks = child.lua([[
    local ns = vim.api.nvim_create_namespace("map-list")
    local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
    local count = 0

    for _, mark in ipairs(marks) do
      if mark[4].hl_group == "Comment" then
        count = count + 1
      end
    end

    vim.cmd("bwipeout!")

    return count
  ]])

  eq(comment_marks >= 2, true)
end

T["applies plugin highlights to rendered plugin rows"] = function()
  local groups = child.lua([[
    vim.api.nvim_set_hl(0, "MapListTestPluginColor", { fg = 0xff0000 })
    require("map-list").setup({
      colors = {
        min_normal_distance = 0,
        min_comment_distance = 0,
        min_background_contrast = 0,
      },
      source_providers = {
        function()
          return "highlight-source.nvim", "plugin"
        end,
      },
    })

    vim.keymap.set("n", "maplistpluginhighlight", function() end, {
      desc = "Map List Test Plugin Highlight",
    })

    vim.cmd("Map maplistpluginhighlight")

    local ns = vim.api.nvim_create_namespace("map-list")
    local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
    local found = {}

    for _, mark in ipairs(marks) do
      local group = mark[4].hl_group
      if type(group) == "string" and group:find("^MapListPlugin") ~= nil then
        found[group] = true
      end
    end

    vim.cmd("bwipeout!")

    return vim.tbl_keys(found)
  ]])

  eq(#groups > 0, true)
end

T["renders empty result message"] = function()
  eq(map_lines("Map maplistmissingneedle"), { "No matching keymaps." })
end

T["truncates long rendered fields without losing source tail"] = function()
  local line = child.lua([[
    local previous_columns = vim.o.columns
    vim.o.columns = 50

    require("map-list.render").open({
      {
        mode = "n",
        lhs = "maplist-" .. string.rep("lhs", 20),
        desc = "Map List Test " .. string.rep("Description", 8),
        source = "/very/long/path/to/map-list/source-tail.lua:123",
        source_kind = "rhs",
      },
    }, {
      colors = {
        min_normal_distance = 0,
        min_comment_distance = 0,
        min_background_contrast = 0,
      },
    })

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    vim.cmd("bwipeout!")
    vim.o.columns = previous_columns

    return lines[1]
  ]])

  contains({ line }, "...")
  contains({ line }, ".lua:123")
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

T["theme color grouping creates plugin highlight groups"] = function()
  local groups = child.lua([[
    vim.api.nvim_set_hl(0, "MapListTestOne", { fg = 0xff0000 })
    vim.api.nvim_set_hl(0, "MapListTestTwo", { fg = 0x00ff00 })
    vim.api.nvim_set_hl(0, "MapListTestThree", { fg = 0x0000ff })

    return require("map-list.colors").plugin_groups({
      { source = "alpha.nvim", source_kind = "plugin" },
      { source = "beta.nvim", source_kind = "plugin" },
    }, {
      min_normal_distance = 0,
      min_comment_distance = 0,
      min_background_contrast = 0,
    })
  ]])

  no_error(function()
    assert(groups["alpha.nvim"] ~= nil)
    assert(groups["beta.nvim"] ~= nil)
  end)
end

return T
