local M = {}

local tracked = {}
local original_keymap_set = nil

--- Builds a stable lookup key for a mode, lhs, and buffer.
local function tracked_key(mode, lhs, buffer)
  return table.concat({ tostring(buffer or 0), mode or "", lhs or "" }, "\0")
end

--- Normalizes a user-facing buffer option to the keymap list buffer id.
local function option_buffer(opts)
  if type(opts) ~= "table" then
    return 0
  end

  if opts.buffer == true then
    return vim.api.nvim_get_current_buf()
  end

  if type(opts.buffer) == "number" then
    return opts.buffer
  end

  return 0
end

--- Converts debug source metadata into the display form used in rows.
local function source_ref(source, line)
  if type(source) ~= "string" or source == "" then
    return nil
  end

  if type(line) ~= "number" or line <= 0 then
    return nil
  end

  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end

  return vim.fn.fnamemodify(source, ":~:.") .. ":" .. line
end

--- Records the caller location for maps created through vim.keymap.set().
local function track_keymap_set(mode, lhs, opts, info)
  if type(lhs) ~= "string" or type(info) ~= "table" then
    return
  end

  if type(mode) == "string" then
    mode = { mode }
  end

  if type(mode) ~= "table" then
    return
  end

  local ref = source_ref(info.source, info.currentline)
  if ref == nil then
    return
  end

  local buffer = option_buffer(opts)
  local normalized_lhs = require("map-list.keys").normalize_lhs(lhs)

  for _, item in ipairs(mode) do
    tracked[tracked_key(item, normalized_lhs, buffer)] = ref
  end
end

--- Looks up the script path for a keymap script id.
local function script_path(script_id)
  if type(script_id) ~= "number" or script_id <= 0 then
    return nil
  end

  for _, script in ipairs(vim.fn.getscriptinfo()) do
    if script.sid == script_id then
      return script.name
    end
  end

  return nil
end

--- Starts capturing callsites for future vim.keymap.set() mappings.
function M.enable_tracking()
  if original_keymap_set ~= nil then
    return
  end

  original_keymap_set = vim.keymap.set

  vim.keymap.set = function(mode, lhs, rhs, opts)
    local info = debug.getinfo(2, "Sl")
    original_keymap_set(mode, lhs, rhs, opts)
    track_keymap_set(mode, lhs, opts, info)
  end
end

--- Extracts a display source reference from keymap script metadata.
function M.map(map, mode)
  local direct = source_ref(script_path(map.sid), map.lnum)
  if direct ~= nil then
    return direct
  end

  return tracked[tracked_key(mode, map.lhs, map.buffer)]
end

return M
