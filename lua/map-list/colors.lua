local M = {}

--- Picks color indices that are spread across the available theme palette.
local function pick_spread_indices(num_colors, num_items)
  local indices = {}

  if num_colors == 0 or num_items == 0 then
    return indices
  end

  if num_items == 1 then
    -- Pick from the middle instead of the first color so a single plugin does
    -- not always get whatever low-value group happens to sort first.
    return { math.ceil(num_colors / 2) }
  end

  local spread_count = math.min(num_items, num_colors)

  for index = 1, num_items do
    if index <= num_colors then
      local position = (num_colors + 1) * index / (spread_count + 1)
      table.insert(indices, math.floor(position + 0.5))
    else
      table.insert(indices, ((index - 1) % num_colors) + 1)
    end
  end

  return indices
end

--- Converts a packed integer color into RGB channels.
local function rgb(color)
  return {
    r = math.floor(color / 0x10000) % 0x100,
    g = math.floor(color / 0x100) % 0x100,
    b = color % 0x100,
  }
end

--- Calculates Euclidean distance between two packed RGB colors.
local function color_distance(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return math.huge
  end

  a = rgb(a)
  b = rgb(b)

  local dr = a.r - b.r
  local dg = a.g - b.g
  local db = a.b - b.b

  return math.sqrt(dr * dr + dg * dg + db * db)
end

--- Converts an sRGB channel to its linear luminance contribution.
local function luminance_channel(value)
  value = value / 255

  if value <= 0.03928 then
    return value / 12.92
  end

  return ((value + 0.055) / 1.055) ^ 2.4
end

--- Calculates WCAG relative luminance for a packed RGB color.
local function relative_luminance(color)
  if type(color) ~= "number" then
    return nil
  end

  color = rgb(color)

  return 0.2126 * luminance_channel(color.r)
    + 0.7152 * luminance_channel(color.g)
    + 0.0722 * luminance_channel(color.b)
end

--- Calculates the WCAG contrast ratio between two packed RGB colors.
local function contrast_ratio(a, b)
  local a_luminance = relative_luminance(a)
  local b_luminance = relative_luminance(b)

  if a_luminance == nil or b_luminance == nil then
    return math.huge
  end

  local lighter = math.max(a_luminance, b_luminance)
  local darker = math.min(a_luminance, b_luminance)

  return (lighter + 0.05) / (darker + 0.05)
end

--- Checks whether a theme color is distinct enough for plugin grouping.
local function usable_plugin_color(color, normal, comment, config)
  if color_distance(color, normal.fg) < config.min_normal_distance then
    return false
  end

  if color_distance(color, comment.fg) < config.min_comment_distance then
    return false
  end

  if contrast_ratio(color, normal.bg) < config.min_background_contrast then
    return false
  end

  return true
end

--- Collects usable foreground colors from the active colorscheme.
local function collect_theme_colors(config)
  local ok, groups = pcall(vim.api.nvim_get_hl, 0, {})
  if not ok then
    return {}
  end

  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local comment = vim.api.nvim_get_hl(0, { name = "Comment" })
  local excluded = {
    [normal.fg or false] = true,
    [comment.fg or false] = true,
  }
  local colors = {}
  local seen = {}

  for group_name in pairs(groups) do
    local group_ok, group = pcall(vim.api.nvim_get_hl, 0, { name = group_name })

    if
      group_ok
      and type(group.fg) == "number"
      and not excluded[group.fg]
      and not seen[group.fg]
      -- Source labels and callback fallbacks already use these baseline
      -- colors, so plugin groups need enough separation to remain scannable.
      and usable_plugin_color(group.fg, normal, comment, config)
    then
      seen[group.fg] = true
      table.insert(colors, group.fg)
    end
  end

  table.sort(colors)

  return colors
end

--- Collects unique plugin source names from rendered map rows.
local function collect_plugin_names(rows)
  local seen = {}
  local names = {}

  for _, row in ipairs(rows) do
    if row.source_kind == "plugin" and not seen[row.source] then
      seen[row.source] = true
      table.insert(names, row.source)
    end
  end

  table.sort(names)

  return names
end

--- Creates highlight groups for plugin-owned rows.
function M.plugin_groups(rows, config)
  local colors = collect_theme_colors(config)
  local plugins = collect_plugin_names(rows)
  local groups = {}

  if #colors == 0 then
    return groups
  end

  local indices = pick_spread_indices(#colors, #plugins)

  for index, plugin_name in ipairs(plugins) do
    local color = colors[indices[index]]
    local group = "MapListPlugin" .. index

    vim.api.nvim_set_hl(0, group, {
      fg = color,
    })

    groups[plugin_name] = group
  end

  return groups
end

return M
