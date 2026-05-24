local keys = require("map-list.keys")
local maps = require("map-list.maps")
local render = require("map-list.render")

local M = {}

local defaults = {
  command = "Map",
  source_providers = { "lazy", "callback", "rhs" },
  color = true,
  output = "buffer",
  window_command = "botright new",
  buffer_name = "Keymaps",
  include_buffer_local = true,
  buffer_local_marker = "@",
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

local function normalize_filter(filter)
  if filter == nil or filter == "" then
    return nil
  end

  local display = filter:lower()

  filter = keys.expand_lhs(filter)

  return {
    display = display,
    has_space = filter:find(" ", 1, true) ~= nil,
    raw = filter:lower(),
  }
end

function M.show(opts)
  local filter = normalize_filter(opts and opts.args or nil)
  render.open(maps.collect(filter, state.config), state.config)
end

function M.setup(opts)
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
