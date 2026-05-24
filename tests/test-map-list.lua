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

T["key helpers expand normalize and display lhs notation"] = function()
  local result = child.lua([[
    local keys = require("map-list.keys")

    return {
      keys.expand_lhs("<leader>x"),
      keys.expand_lhs("<localleader>x"),
      keys.expand_lhs("<Space>x"),
      keys.normalize_lhs("<Space>x"),
      keys.display_lhs(" x"),
      keys.display_lhs(",x"),
    }
  ]])

  eq(result, {
    " x",
    ",x",
    " x",
    " x",
    "<leader>x",
    "<localleader>x",
  })
end

T["key helpers handle empty and overlapping leaders"] = function()
  local result = child.lua([[
    local keys = require("map-list.keys")

    vim.g.mapleader = ""
    vim.g.maplocalleader = ""
    local empty = {
      keys.expand_lhs("<leader>x"),
      keys.display_lhs("x"),
    }

    vim.g.mapleader = ","
    vim.g.maplocalleader = ",,"

    return {
      empty[1],
      empty[2],
      keys.display_lhs(",,x"),
      keys.display_lhs(",x"),
      keys.normalize_lhs("<Tab>x"),
    }
  ]])

  eq(result, {
    "x",
    "x",
    "<localleader>x",
    "<leader>x",
    "\tx",
  })
end

T["maps.collect returns sorted rows with buffer markers and fallback sources"] = function()
  local rows = child.lua([[
    local maps = require("map-list.maps")

    vim.keymap.set("n", "maplistcollectb", function() end, {
      desc = "Map List Collect B",
    })
    vim.keymap.set("n", "maplistcollectA", function() end, {
      desc = "Map List Collect Upper",
    })
    vim.keymap.set("n", "maplistcollecta", function() end, {
      desc = "Map List Collect Lower",
    })
    vim.keymap.set("n", "maplistcollectbuffer", function() end, {
      buffer = true,
      desc = "Map List Collect Buffer",
    })

    return maps.collect({
      raw = "maplistcollect",
      display = "maplistcollect",
      has_space = false,
    }, {})
  ]])

  eq(rows[1].desc, "Map List Collect Lower")
  eq(rows[2].desc, "Map List Collect Upper")
  eq(rows[3].desc, "Map List Collect B")

  local buffer_row = nil
  for _, row in ipairs(rows) do
    if row.desc == "Map List Collect Buffer" then
      buffer_row = row
    end
  end

  no_error(function()
    assert(buffer_row ~= nil)
    assert(buffer_row.mode == "n@")
    assert(buffer_row.source:find("[string", 1, true) ~= nil)
    assert(buffer_row.source_kind == "callback")
  end)
end

T["maps.collect resolves package provider sources"] = function()
  local result = child.lua([[
    local maps = require("map-list.maps")

    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          contextual = {
            name = "contextual.nvim",
            keys = {
              { "maplistcontext", mode = "n" },
            },
          },
        },
      }
    end

    vim.keymap.set("n", "maplistcontext", function() end, {
      desc = "Map List Context",
    })

    local rows = maps.collect({
      raw = "maplistcontext",
      display = "maplistcontext",
      has_space = false,
    }, {})

    return {
      rows[1].source,
      rows[1].source_kind,
    }
  ]])

  eq(result, {
    "contextual.nvim",
    "plugin",
  })
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

T["can exclude buffer-local mappings"] = function()
  child.lua([[
    require("map-list").setup({ include_buffer_local = false })

    vim.keymap.set("n", "maplistbufferconfigglobal", function() end, {
      desc = "Map List Global",
    })
    vim.keymap.set("n", "maplistbufferconfiglocal", function() end, {
      buffer = true,
      desc = "Map List Local",
    })
  ]])

  local lines = map_lines("Map maplistbufferconfig")

  contains(lines, "Map List Global")
  rejects(lines, "Map List Local")
end

T["can configure buffer-local marker"] = function()
  child.lua([[
    require("map-list").setup({ buffer_local_marker = "*" })

    vim.keymap.set("n", "maplistbuffermarker", function() end, {
      buffer = true,
      desc = "Map List Buffer Marker",
    })
  ]])

  local lines = map_lines("Map maplistbuffermarker")

  expect_match(contains(lines, "Map List Buffer Marker"), "^n%*%s+")
end

T["can configure collected modes"] = function()
  child.lua([[
    require("map-list").setup({
      modes = {
        { key = "n", label = "normal" },
      },
    })

    vim.keymap.set("n", "maplistmodeconfig", function() end, {
      desc = "Map List Mode Config Normal",
    })
    vim.keymap.set("i", "maplistmodeconfig", function() end, {
      desc = "Map List Mode Config Insert",
    })
  ]])

  local lines = map_lines("Map maplistmodeconfig")

  expect_match(contains(lines, "Map List Mode Config Normal"), "^normal%s+")
  rejects(lines, "Map List Mode Config Insert")
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
    })
    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          highlight = {
            name = "highlight-source.nvim",
            keys = {
              { "maplistpluginhighlight", mode = "n" },
            },
          },
        },
      }
    end

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

T["color output can be disabled"] = function()
  local mark_count = child.lua([[
    require("map-list").setup({
      color = false,
      colors = {
        min_normal_distance = 0,
        min_comment_distance = 0,
        min_background_contrast = 0,
      },
    })
    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          no_color = {
            name = "no-color-plugin.nvim",
            keys = {
              { "<leader>maplistnocolor", mode = "n" },
            },
          },
        },
      }
    end

    vim.keymap.set("n", "<leader>maplistnocolor", function() end, {
      desc = "Map List No Color",
    })

    vim.cmd("Map maplistnocolor")

    local ns = vim.api.nvim_create_namespace("map-list")
    local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })

    vim.cmd("bwipeout!")

    return #marks
  ]])

  eq(mark_count, 0)
end

T["can render command output as messages"] = function()
  local result = child.lua([[
    require("map-list").setup({ output = "messages" })

    vim.keymap.set("n", "maplistmessages", function() end, {
      desc = "Map List Messages",
    })

    local before_buf = vim.api.nvim_get_current_buf()
    vim.cmd("Map maplistmessages")
    local after_buf = vim.api.nvim_get_current_buf()

    return {
      before_buf == after_buf,
      vim.bo[after_buf].buftype,
      vim.api.nvim_exec2("messages", { output = true }).output,
    }
  ]])

  eq(result[1], true)
  eq(result[2], "")
  contains({ result[3] }, "Map List Messages")
end

T["can configure buffer window command and name"] = function()
  local result = child.lua([[
    require("map-list").setup({
      window_command = "enew",
      buffer_name = "Configured Keymaps",
    })

    vim.keymap.set("n", "maplistbuffername", function() end, {
      desc = "Map List Buffer Name",
    })

    local before_windows = #vim.api.nvim_list_wins()
    vim.cmd("Map maplistbuffername")

    local result = {
      windows_unchanged = #vim.api.nvim_list_wins() == before_windows,
      name = vim.api.nvim_buf_get_name(0),
      buftype = vim.bo.buftype,
    }

    vim.cmd("bwipeout!")

    return result
  ]])

  eq(result.windows_unchanged, true)
  expect_match(result.name, "Configured Keymaps$")
  eq(result.buftype, "nofile")
end

T["renders empty result message"] = function()
  eq(map_lines("Map maplistmissingneedle"), { "No matching keymaps." })
end

T["format.rows renders empty rows without highlights"] = function()
  local result = child.lua([[
    local lines, highlights = require("map-list.format").rows({}, {
      colors = {
        min_normal_distance = 0,
        min_comment_distance = 0,
        min_background_contrast = 0,
      },
    })

    return { lines, highlights }
  ]])

  eq(result, { { "No matching keymaps." }, {} })
end

T["format.rows uses a compact mode column"] = function()
  local lines = child.lua([[
    local lines = require("map-list.format").rows({
      {
        mode = "n",
        lhs = "lhs",
        desc = "desc",
        source = "source",
        source_kind = "rhs",
      },
    }, {
      colors = {
        min_normal_distance = 0,
        min_comment_distance = 0,
        min_background_contrast = 0,
      },
    })

    return lines
  ]])

  eq(lines[1]:sub(1, 8), "n   lhs ")
end

T["format.rows returns plugin and callback highlight spans"] = function()
  local result = child.lua([[
    vim.o.columns = 120
    vim.api.nvim_set_hl(0, "MapListTestFormatPluginColor", { fg = 0xff0000 })

    local lines, highlights = require("map-list.format").rows({
      {
        mode = "n",
        lhs = "maplistformatplugin",
        desc = "Map List Format Plugin",
        source = "format-plugin.nvim",
        source_kind = "plugin",
      },
      {
        mode = "n",
        lhs = "maplistformatcallback",
        desc = "Map List Format Callback",
        source = "callback-source.lua:42",
        source_kind = "callback",
      },
    }, {
      color = true,
      colors = {
        min_normal_distance = 0,
        min_comment_distance = 0,
        min_background_contrast = 0,
      },
    })

    local plugin_count = 0
    local callback_count = 0

    for _, highlight in ipairs(highlights) do
      if highlight.group:find("^MapListPlugin") ~= nil then
        plugin_count = plugin_count + 1
      elseif highlight.group == "Comment" then
        callback_count = callback_count + 1
      end
    end

    return {
      lines = lines,
      plugin_count = plugin_count,
      callback_count = callback_count,
    }
  ]])

  contains(result.lines, "format-plugin.nvim")
  contains(result.lines, "callback-source.lua:42")
  eq(result.plugin_count >= 2, true)
  eq(result.callback_count, 1)
end

T["format.rows truncates paths from left and names from right"] = function()
  local result = child.lua([[
    local previous_columns = vim.o.columns
    vim.o.columns = 40

    local lines = require("map-list.format").rows({
      {
        mode = "n",
        lhs = "short",
        desc = "desc",
        source = "/very/long/path/to/source-tail.lua:123",
        source_kind = "rhs",
      },
      {
        mode = "n",
        lhs = "short",
        desc = "desc",
        source = "very-long-plugin-source-name.nvim",
        source_kind = "rhs",
      },
    }, {
      colors = {
        min_normal_distance = 0,
        min_comment_distance = 0,
        min_background_contrast = 0,
      },
    })

    vim.o.columns = previous_columns

    return lines
  ]])

  contains({ result[1] }, "...")
  contains({ result[1] }, ".lua:123")
  contains({ result[2] }, "very-long-plugin")
  contains({ result[2] }, "...")
  rejects({ result[2] }, ".nvim")
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
