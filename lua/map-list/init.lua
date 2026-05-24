local render = require("map-list.render")
local sources = require("map-list.sources")

local M = {}

local defaults = {
  command = "Map",
  source_providers = { "lazy", "callback", "rhs" },
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

local modes = {
  { key = "n", label = "n" },
  { key = "v", label = "v" },
  { key = "x", label = "x" },
  { key = "s", label = "s" },
  { key = "o", label = "o" },
  { key = "i", label = "i" },
  { key = "c", label = "c" },
  { key = "t", label = "t" },
}

local function normalize_filter(filter)
  if filter == nil or filter == "" then
    return nil
  end

  local leader = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"
  local display = filter:lower()

  filter = filter:gsub("<[Ll]eader>", leader)
  filter = filter:gsub("<[Ll]ocal[Ll]eader>", localleader)
  filter = filter:gsub("<[Ss]pace>", " ")

  return {
    display = display,
    has_space = filter:find(" ", 1, true) ~= nil,
    raw = filter:lower(),
  }
end

local function replace_prefix(text, prefix, replacement)
  if prefix == nil or prefix == "" then
    return text
  end

  if text:sub(1, #prefix) == prefix then
    return replacement .. text:sub(#prefix + 1)
  end

  return text
end

local function display_lhs(lhs)
  local leader = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"

  lhs = replace_prefix(lhs, leader, "<leader>")
  lhs = replace_prefix(lhs, localleader, "<localleader>")

  return lhs:gsub(" ", "<Space>")
end

local function include_map(map, filter)
  if filter == nil then
    return true
  end

  local lhs = (map.lhs or ""):lower()
  local lhs_display = display_lhs(map.lhs or ""):lower()

  if filter.has_space then
    return lhs:sub(1, #filter.raw) == filter.raw
      or lhs_display:find(filter.display, 1, true) ~= nil
  end

  if
    lhs:find(filter.raw, 1, true) ~= nil
    or lhs_display:find(filter.display, 1, true) ~= nil
  then
    return true
  end

  if filter.raw:match("%S") == nil then
    return false
  end

  local haystack = table.concat({ map.desc or "", map.rhs or "" }, " "):lower()

  return haystack:find(filter.raw, 1, true) ~= nil
    or haystack:find(filter.display, 1, true) ~= nil
end

local function sort_key(text)
  return text:gsub(".", function(char)
    if char:match("%a") then
      local lower = char:lower()
      local case_rank = char == lower and "0" or "1"

      return lower .. case_rank
    end

    return char .. "0"
  end)
end

local function map_source(map, mode, source_context)
  for _, provider in ipairs(state.config.source_providers) do
    local source, source_kind =
      sources.resolve(provider, map, mode, source_context)

    if source ~= nil then
      return source, source_kind
    end
  end

  return "<Lua function>", "rhs"
end

local function append_map(rows, map, mode_label, mode_key, source_context)
  local source, source_kind = map_source(map, mode_key, source_context)

  table.insert(rows, {
    mode = mode_label,
    lhs = display_lhs(map.lhs),
    desc = map.desc or "",
    source = source,
    source_kind = source_kind,
  })
end

local function collect_maps(filter)
  local rows = {}
  local current_buf = vim.api.nvim_get_current_buf()
  local source_context = sources.context()

  for _, mode in ipairs(modes) do
    for _, map in ipairs(vim.api.nvim_get_keymap(mode.key)) do
      if include_map(map, filter) then
        append_map(rows, map, mode.label, mode.key, source_context)
      end
    end

    for _, map in ipairs(vim.api.nvim_buf_get_keymap(current_buf, mode.key)) do
      if include_map(map, filter) then
        append_map(rows, map, mode.label .. "@", mode.key, source_context)
      end
    end
  end

  table.sort(rows, function(a, b)
    local a_lhs = sort_key(a.lhs)
    local b_lhs = sort_key(b.lhs)

    if a_lhs == b_lhs then
      if a.lhs == b.lhs then
        return a.mode < b.mode
      end

      return a.lhs < b.lhs
    end

    return a_lhs < b_lhs
  end)

  return rows
end

function M.show(opts)
  local filter = normalize_filter(opts and opts.args or nil)
  render.open(collect_maps(filter), state.config)
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
