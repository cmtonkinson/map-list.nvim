local format = require("map-list.format")
local map_list = require("map-list")

local M = {}

--- Builds text used for Telescope filtering and sorting.
local function ordinal(row)
  return table.concat({
    row.mode or "",
    row.lhs or "",
    row.desc or "",
    row.source or "",
    row.source_ref or "",
  }, " ")
end

--- Indexes formatted display lines by their source row table.
local function display_by_row(rows, lines)
  local displays = {}

  for index, row in ipairs(rows) do
    displays[row] = lines[index]
  end

  return displays
end

--- Opens map-list rows in a Telescope picker.
function M.map_list(opts)
  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  local rows = map_list.rows(opts.filter)
  local lines = format.rows(rows, map_list.config())
  local displays = display_by_row(rows, lines)

  pickers
    .new(opts, {
      prompt_title = "Keymaps",
      finder = finders.new_table({
        results = rows,
        entry_maker = function(row)
          return {
            value = row,
            ordinal = ordinal(row),
            display = displays[row],
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
    })
    :find()
end

return M
