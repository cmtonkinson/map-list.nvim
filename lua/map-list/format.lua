local colors = require("map-list.colors")

local M = {}

--- Truncates text on the right without exceeding display width.
local function truncate(text, width)
  if width <= 0 then
    return ""
  end

  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end

  if width <= 3 then
    return string.sub("...", 1, width)
  end

  local out = ""
  local used = 0
  local length = vim.fn.strchars(text)

  for index = 0, length - 1 do
    local part = vim.fn.strcharpart(text, index, 1)
    local part_width = vim.fn.strdisplaywidth(part)

    if used + part_width > width - 3 then
      break
    end

    out = out .. part
    used = used + part_width
  end

  return out .. "..."
end

--- Truncates text on the left without exceeding display width.
local function truncate_left(text, width)
  if width <= 0 then
    return ""
  end

  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end

  if width <= 3 then
    return string.sub("...", 1, width)
  end

  local out = ""
  local used = 0
  local length = vim.fn.strchars(text)

  for index = length - 1, 0, -1 do
    local part = vim.fn.strcharpart(text, index, 1)
    local part_width = vim.fn.strdisplaywidth(part)

    if used + part_width > width - 3 then
      break
    end

    out = part .. out
    used = used + part_width
  end

  return "..." .. out
end

--- Formats a source column value for the available display width.
local function source_display(source, width)
  if source == "<Lua function>" then
    return truncate(source, width)
  end

  if source:find("/", 1, true) ~= nil or source:find(":", 1, true) ~= nil then
    -- File paths and line references are usually most useful at the tail,
    -- where the filename and line number live.
    return truncate_left(source, width)
  end

  return truncate(source, width)
end

--- Pads text to a fixed display width.
local function pad(text, width)
  local padding = width - vim.fn.strdisplaywidth(text)
  if padding <= 0 then
    return text
  end

  return text .. string.rep(" ", padding)
end

--- Finds the widest row value for a column with a minimum fallback.
local function max_width(rows, key, fallback)
  local width = fallback

  for _, row in ipairs(rows) do
    width = math.max(width, vim.fn.strdisplaywidth(row[key] or ""))
  end

  return width
end

--- Converts collected keymap rows into aligned display lines and highlights.
function M.rows(rows, config)
  if #rows == 0 then
    return { "No matching keymaps." }, {}
  end

  local columns = vim.o.columns
  local mode_width = max_width(rows, "mode", 2)
  local lhs_width = math.min(max_width(rows, "lhs", 3), 28)
  local desc_width =
    math.min(max_width(rows, "desc", 4), math.floor(columns * 0.35))
  local fixed_width = mode_width + 2 + lhs_width + 2 + desc_width + 2
  -- The source column is the least predictable column, so descriptions are
  -- capped first and any remaining width is left for source attribution.
  local source_width = math.max(columns - fixed_width, 12)
  local lines = {}
  local highlights = {}
  local plugin_groups = {}

  if config.color then
    plugin_groups = colors.plugin_groups(rows, config.colors)
  end

  for _, row in ipairs(rows) do
    local desc = truncate(row.desc, desc_width)
    local source = source_display(row.source, source_width)
    local desc_start = mode_width + 2 + lhs_width + 2
    local source_start = desc_start + desc_width + 2
    local line = table.concat({
      pad(row.mode, mode_width),
      pad(truncate(row.lhs, lhs_width), lhs_width),
      pad(desc, desc_width),
      source,
    }, "  ")

    if row.source_kind == "plugin" then
      local group = plugin_groups[row.source]

      if group ~= nil and desc ~= "" then
        table.insert(highlights, {
          group = group,
          line = #lines,
          start_col = desc_start,
          end_col = desc_start + #desc,
        })
      end

      if group ~= nil then
        table.insert(highlights, {
          group = group,
          line = #lines,
          start_col = source_start,
          end_col = source_start + #source,
        })
      end
    end

    if config.color and row.source_kind == "callback" then
      table.insert(highlights, {
        group = "Comment",
        line = #lines,
        start_col = #line - #source,
        end_col = #line,
      })
    end

    table.insert(lines, line)
  end

  return lines, highlights
end

return M
