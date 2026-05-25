local keys = require("map-list.keys")
local maps = require("map-list.maps")
local render = require("map-list.render")
local source_location = require("map-list.source-location")

local M = {}

local defaults = {
  command = "Map",
  color = true,
  output = "buffer",
  window_command = "botright new",
  buffer_name = "Keymaps",
  include_buffer_local = true,
  buffer_local_marker = "@",
  collapse_modes = true,
  show_rhs_source = true,
  modes = { "n", "v", "x", "s", "o", "i", "c", "t" },
  colors = {
    min_normal_distance = 45,
    min_comment_distance = 35,
    min_background_contrast = 2.0,
  },
}

local state = {
  command_created = nil,
  config = vim.deepcopy(defaults),
}

--- Normalizes a user command filter into raw and display search forms.
local function normalize_filter(filter)
  if filter == nil or filter == "" then
    return nil
  end

  -- Plugin filter: case-insensitive substring against the resolved plugin
  -- name. Bare "@" matches every plugin-attributed mapping.
  if filter:sub(1, 1) == "@" then
    return {
      kind = "plugin",
      query = filter:sub(2):lower(),
    }
  end

  -- Ex-command filter: case-sensitive substring against the RHS Ex command
  -- name. Bare ":" matches every mapping whose RHS invokes an Ex command.
  if filter:sub(1, 1) == ":" then
    return {
      kind = "command",
      query = filter:sub(2),
    }
  end

  local display = filter:lower()

  filter = keys.expand_lhs(filter)

  return {
    kind = "default",
    display = display,
    has_space = filter:find(" ", 1, true) ~= nil,
    raw = filter:lower(),
  }
end

--- Renders the keymap list for the current command invocation.
function M.show(opts)
  local filter = normalize_filter(opts and opts.args or nil)
  render.open(maps.collect(filter, state.config), state.config)
end

--- Configures map-list and creates the user command.
function M.setup(opts)
  source_location.enable_tracking()

  state.config =
    vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  if state.command_created ~= nil then
    pcall(vim.api.nvim_del_user_command, state.command_created)
  end

  vim.api.nvim_create_user_command(state.config.command, M.show, {
    nargs = "?",
    desc = "List keymaps compactly",
  })

  state.command_created = state.config.command
end

return M
