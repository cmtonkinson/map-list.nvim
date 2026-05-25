local helpers = require("tests.helpers")
local child = helpers.child
local map_lines = helpers.map_lines
local contains = helpers.contains
local rejects = helpers.rejects
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

--- Configures the shared fixture used by both @ and : prefix tests.
---
--- Plugin attribution is wired through a faked lazy.core.config so that the
--- three plugin-owned lhs values resolve to known plugin names. The remaining
--- mappings cover Ex-command RHSs without plugin attribution, a Lua callback
--- RHS, and a plain non-command RHS so the prefix filters can be checked
--- against the full set of RHS shapes.
local function configure_fixture()
  child.lua([[
    package.loaded["lazy.core.config"] = nil
    package.preload["lazy.core.config"] = function()
      return {
        plugins = {
          telescope = {
            name = "telescope.nvim",
            keys = {
              { "maplistprefixtelescope", mode = "n" },
            },
          },
          gitsigns = {
            name = "gitsigns.nvim",
            keys = {
              { "maplistprefixgitsigns", mode = "n" },
            },
          },
          neogit = {
            name = "neogit.nvim",
            keys = {
              { "maplistprefixneogit", mode = "n" },
            },
          },
        },
      }
    end

    vim.keymap.set("n", "maplistprefixtelescope",
      "<Cmd>Telescope find_files<CR>",
      { desc = "MapList Prefix Telescope" })

    vim.keymap.set("n", "maplistprefixgitsigns",
      "<Cmd>Gitsigns blame_line<CR>",
      { desc = "MapList Prefix Gitsigns" })

    vim.keymap.set("n", "maplistprefixneogit",
      "<Cmd>Neogit<CR>",
      { desc = "MapList Prefix Neogit" })

    vim.keymap.set("n", "maplistprefixnohl",
      "<Cmd>nohlsearch<CR>",
      { desc = "MapList Prefix Nohl" })

    vim.keymap.set("n", "maplistprefixwrite",
      ":write<CR>",
      { desc = "MapList Prefix Write" })

    vim.keymap.set("n", "maplistprefixcallback",
      function() end,
      { desc = "MapList Prefix Callback" })

    vim.keymap.set("n", "maplistprefixmotion", "gj",
      { desc = "MapList Prefix Motion" })
  ]])
end

-- @ prefix --------------------------------------------------------------

T["@ matches every plugin-attributed mapping"] = function()
  configure_fixture()

  local lines = map_lines("Map @")

  contains(lines, "MapList Prefix Telescope")
  contains(lines, "MapList Prefix Gitsigns")
  contains(lines, "MapList Prefix Neogit")
  rejects(lines, "MapList Prefix Nohl")
  rejects(lines, "MapList Prefix Write")
  rejects(lines, "MapList Prefix Callback")
  rejects(lines, "MapList Prefix Motion")
end

T["@name substring-matches the plugin name"] = function()
  configure_fixture()

  local lines = map_lines("Map @telescope")

  contains(lines, "MapList Prefix Telescope")
  rejects(lines, "MapList Prefix Gitsigns")
  rejects(lines, "MapList Prefix Neogit")
end

T["@name absorbs .nvim suffix via substring"] = function()
  configure_fixture()

  contains(map_lines("Map @gitsigns"), "MapList Prefix Gitsigns")
  contains(map_lines("Map @gitsigns.nvim"), "MapList Prefix Gitsigns")
end

T["@partial matches every plugin whose name contains the substring"] = function()
  configure_fixture()

  local lines = map_lines("Map @git")

  contains(lines, "MapList Prefix Gitsigns")
  contains(lines, "MapList Prefix Neogit")
  rejects(lines, "MapList Prefix Telescope")
end

T["@name is case-insensitive"] = function()
  configure_fixture()

  contains(map_lines("Map @TELESCOPE"), "MapList Prefix Telescope")
  contains(map_lines("Map @TeLeScOpE"), "MapList Prefix Telescope")
end

T["@name with no matches reports the empty result"] = function()
  configure_fixture()

  eq(map_lines("Map @maplistprefixnonexistent"), { "No matching keymaps." })
end

T["@ attributes via vim-plug RHS ownership"] = function()
  -- Confirms the @ filter is provider-agnostic: a mapping whose lhs has no
  -- lazy-keys spec but whose RHS invokes a user command defined inside a
  -- vim-plug plugin directory must still match @<plugin>.
  child.lua([[
    local plugin_dir = vim.fn.tempname() .. "/plugged/git-blame.nvim"
    vim.fn.mkdir(plugin_dir .. "/plugin", "p")
    vim.fn.writefile({
      "vim.api.nvim_create_user_command('MapListPrefixGitBlame', function() end, {})",
    }, plugin_dir .. "/plugin/git-blame.lua")

    vim.g.plugs = {
      ["git-blame.nvim"] = { dir = plugin_dir },
    }

    vim.keymap.set("n", "maplistprefixvimplug",
      "<Cmd>MapListPrefixGitBlame<CR>",
      { desc = "MapList Prefix VimPlug" })
  ]])

  local lines = map_lines("Map @git-blame")

  contains(lines, "MapList Prefix VimPlug")
end

-- : prefix --------------------------------------------------------------

T[": matches every mapping whose RHS invokes an Ex command"] = function()
  configure_fixture()

  local lines = map_lines("Map :")

  contains(lines, "MapList Prefix Telescope")
  contains(lines, "MapList Prefix Gitsigns")
  contains(lines, "MapList Prefix Neogit")
  contains(lines, "MapList Prefix Nohl")
  contains(lines, "MapList Prefix Write")
  rejects(lines, "MapList Prefix Callback")
  rejects(lines, "MapList Prefix Motion")
end

T[":Name substring-matches the Ex command name"] = function()
  configure_fixture()

  local lines = map_lines("Map :Telescope")

  contains(lines, "MapList Prefix Telescope")
  rejects(lines, "MapList Prefix Gitsigns")
  rejects(lines, "MapList Prefix Neogit")
  rejects(lines, "MapList Prefix Nohl")
  rejects(lines, "MapList Prefix Write")
  rejects(lines, "MapList Prefix Callback")
end

T[":name matches both <Cmd>X<CR> and :X<CR> RHS forms"] = function()
  configure_fixture()

  contains(map_lines("Map :nohl"), "MapList Prefix Nohl")
  contains(map_lines("Map :write"), "MapList Prefix Write")
end

T[":Name does not match Lua-callback RHSs"] = function()
  configure_fixture()

  -- A callback whose body happens to invoke a telescope-named command must
  -- still not match :Telescope, since the RHS is a function rather than an
  -- Ex command string.
  child.lua([[
    vim.keymap.set("n", "maplistprefixluatelescope", function()
      vim.cmd("Telescope find_files")
    end, { desc = "MapList Prefix Lua Telescope" })
  ]])

  local lines = map_lines("Map :Telescope")

  contains(lines, "MapList Prefix Telescope")
  rejects(lines, "MapList Prefix Lua Telescope")
end

T[":Name is case-sensitive"] = function()
  configure_fixture()

  rejects(map_lines("Map :NoHl"), "MapList Prefix Nohl")
  rejects(map_lines("Map :telescope"), "MapList Prefix Telescope")
  rejects(map_lines("Map :TELESCOPE"), "MapList Prefix Telescope")
end

T[":Name with no matches reports the empty result"] = function()
  configure_fixture()

  eq(map_lines("Map :MapListPrefixNonexistent"), { "No matching keymaps." })
end

-- Boundaries shared between @ and : -------------------------------------

T["bare @ and bare : are distinguished from substring filters"] = function()
  configure_fixture()

  -- Bare @ matches plugin-attributed only.
  local at_lines = map_lines("Map @")
  rejects(at_lines, "MapList Prefix Nohl")

  -- Bare : matches Ex-command RHSs (including the plugin-attributed ones,
  -- whose RHSs are also Ex commands).
  local colon_lines = map_lines("Map :")
  contains(colon_lines, "MapList Prefix Nohl")
end

T["@ and : prefixes do not bleed into the default filter behavior"] = function()
  -- A literal lhs containing an @ or : in a non-prefix position must still
  -- be findable through the default substring filter.
  child.lua([[
    vim.keymap.set("n", "maplistprefixatinside",
      "<Cmd>echo 'inside'<CR>",
      { desc = "MapList Prefix At Inside @inside" })
  ]])

  contains(map_lines("Map inside"), "MapList Prefix At Inside")
end

return T
