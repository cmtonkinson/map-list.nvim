local colors = require("map-list.colors")

local M = {}
local namespace = vim.api.nvim_create_namespace("map-list")

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

local function source_display(source, width)
  if source == "<Lua function>" then
    return truncate(source, width)
  end

  if source:find("/", 1, true) ~= nil or source:find(":", 1, true) ~= nil then
    return truncate_left(source, width)
  end

  return truncate(source, width)
end

local function pad(text, width)
  local padding = width - vim.fn.strdisplaywidth(text)
  if padding <= 0 then
    return text
  end

  return text .. string.rep(" ", padding)
end

local function max_width(rows, key, fallback)
  local width = fallback

  for _, row in ipairs(rows) do
    width = math.max(width, vim.fn.strdisplaywidth(row[key] or ""))
  end

  return width
end

local function format_rows(rows, config)
  if #rows == 0 then
    return { "No matching keymaps." }, {}
  end

  local columns = vim.o.columns
  local mode_width = max_width(rows, "mode", 4)
  local lhs_width = math.min(max_width(rows, "lhs", 3), 28)
  local desc_width =
    math.min(max_width(rows, "desc", 4), math.floor(columns * 0.35))
  local fixed_width = mode_width + 2 + lhs_width + 2 + desc_width + 2
  local source_width = math.max(columns - fixed_width, 12)
  local lines = {}
  local highlights = {}
  local plugin_groups = colors.plugin_groups(rows, config.colors)

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

    if row.source_kind == "callback" then
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

local function dim_lhs_leaders(buf, lines)
  for line_number, line in ipairs(lines) do
    local search_start = 1

    while true do
      local start_index, end_index =
        line:find("<localleader>", search_start, true)
      if start_index == nil then
        start_index, end_index = line:find("<leader>", search_start, true)
      end

      if start_index == nil then
        break
      end

      vim.api.nvim_buf_set_extmark(
        buf,
        namespace,
        line_number - 1,
        start_index - 1,
        {
          end_col = end_index,
          hl_group = "Comment",
        }
      )

      search_start = end_index + 1
    end
  end
end

local function apply_highlights(buf, highlights)
  for _, highlight in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(
      buf,
      namespace,
      highlight.line,
      highlight.start_col,
      {
        end_col = highlight.end_col,
        hl_group = highlight.group,
      }
    )
  end
end

function M.open(rows, config)
  local lines, highlights = format_rows(rows, config)

  vim.cmd("botright new")

  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "map-list"
  vim.api.nvim_buf_set_name(buf, "Keymaps")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  dim_lhs_leaders(buf, lines)
  apply_highlights(buf, highlights)
  vim.bo[buf].modifiable = false
  vim.wo.wrap = false
  vim.wo.number = false
  vim.wo.relativenumber = false
end

return M
