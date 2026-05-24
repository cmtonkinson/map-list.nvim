local format = require("map-list.format")

local M = {}
local namespace = vim.api.nvim_create_namespace("map-list")

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

local function print_messages(lines)
  for _, line in ipairs(lines) do
    vim.cmd.echomsg(vim.fn.string(line))
  end
end

function M.open(rows, config)
  local lines, highlights = format.rows(rows, config)

  if config.output == "messages" then
    print_messages(lines)
    return
  end

  vim.cmd(config.window_command or "botright new")

  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "map-list"
  vim.api.nvim_buf_set_name(buf, config.buffer_name or "Keymaps")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if config.color then
    dim_lhs_leaders(buf, lines)
  end
  apply_highlights(buf, highlights)
  vim.bo[buf].modifiable = false
  vim.wo.wrap = false
  vim.wo.number = false
  vim.wo.relativenumber = false
end

return M
