local keys = require("map-list.keys")
local source_registry = require("map-list.source-registry")

local M = {}
local default_modes = { "n", "v", "x", "s", "o", "i", "c", "t" }

local function include_map(map, filter)
  if filter == nil then
    return true
  end

  local lhs = (map.lhs or ""):lower()
  local lhs_display = keys.display_lhs(map.lhs or ""):lower()

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

local function map_source(map, mode, config, source_context)
  for _, provider in ipairs(config.source_providers) do
    local source, source_kind =
      source_registry.resolve(provider, map, mode, source_context)

    if source ~= nil then
      return source, source_kind
    end
  end

  return "<Lua function>", "rhs"
end

local function append_map(
  rows,
  map,
  mode_label,
  mode_key,
  config,
  source_context
)
  local source, source_kind = map_source(map, mode_key, config, source_context)

  table.insert(rows, {
    mode = mode_label,
    lhs = keys.display_lhs(map.lhs),
    desc = map.desc or "",
    source = source,
    source_kind = source_kind,
  })
end

local function sort_rows(rows)
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
end

local function mode_spec(mode)
  if type(mode) == "table" then
    return mode.key, mode.label or mode.key
  end

  return mode, mode
end

function M.collect(filter, config)
  local rows = {}
  local current_buf = vim.api.nvim_get_current_buf()
  local source_context = source_registry.context()
  local modes = config.modes or default_modes
  local buffer_local_marker = config.buffer_local_marker or "@"

  for _, mode in ipairs(modes) do
    local mode_key, mode_label = mode_spec(mode)

    for _, map in ipairs(vim.api.nvim_get_keymap(mode_key)) do
      if include_map(map, filter) then
        append_map(rows, map, mode_label, mode_key, config, source_context)
      end
    end

    if config.include_buffer_local ~= false then
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(current_buf, mode_key)) do
        if include_map(map, filter) then
          append_map(
            rows,
            map,
            mode_label .. buffer_local_marker,
            mode_key,
            config,
            source_context
          )
        end
      end
    end
  end

  sort_rows(rows)

  return rows
end

return M
