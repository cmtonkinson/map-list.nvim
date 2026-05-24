local keys = require("map-list.keys")
local source_registry = require("map-list.source-registry")

local M = {}
local default_modes = { "n", "v", "x", "s", "o", "i", "c", "t" }

--- Checks whether a keymap matches the current filter.
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

--- Builds a case-aware sort key that orders lowercase before uppercase.
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

--- Resolves the source label and kind for a keymap.
local function map_source(map, mode, source_context)
  local source, source_kind = source_registry.resolve(map, mode, source_context)

  return source or "<Lua function>", source_kind or "rhs"
end

--- Adds one collected keymap row to the result list.
local function append_map(
  rows,
  map,
  mode_label,
  mode_suffix,
  mode_key,
  source_context
)
  local source, source_kind = map_source(map, mode_key, source_context)

  table.insert(rows, {
    mode = mode_label .. mode_suffix,
    mode_label = mode_label,
    mode_labels = { [mode_label] = true },
    mode_suffix = mode_suffix,
    lhs = keys.display_lhs(map.lhs),
    desc = map.desc or "",
    source = source,
    source_kind = source_kind,
  })
end

--- Collapses identical mappings across modes into one row.
local function collapse_rows(rows)
  local collapsed = {}
  local by_key = {}

  for _, row in ipairs(rows) do
    local key = table.concat({
      row.lhs,
      row.desc,
      row.source,
      row.source_kind,
      row.mode_suffix,
    }, "\0")
    local existing = by_key[key]

    if existing == nil then
      by_key[key] = row
      table.insert(collapsed, row)
    elseif not existing.mode_labels[row.mode_label] then
      existing.mode_labels[row.mode_label] = true
      existing.mode_label = existing.mode_label .. row.mode_label
      existing.mode = existing.mode_label .. existing.mode_suffix
    end
  end

  return collapsed
end

--- Sorts rows by lhs, then exact lhs text, then collected mode label.
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

--- Normalizes a configured mode entry into API key and display label.
local function mode_spec(mode)
  if type(mode) == "table" then
    return mode.key, mode.label or mode.key
  end

  return mode, mode
end

--- Collects global and configured buffer-local keymaps into display rows.
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
        append_map(rows, map, mode_label, "", mode_key, source_context)
      end
    end

    if config.include_buffer_local ~= false then
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(current_buf, mode_key)) do
        if include_map(map, filter) then
          append_map(
            rows,
            map,
            mode_label,
            buffer_local_marker,
            mode_key,
            source_context
          )
        end
      end
    end
  end

  if config.collapse_modes ~= false then
    rows = collapse_rows(rows)
  end

  sort_rows(rows)

  return rows
end

return M
