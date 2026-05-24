local M = {}

--- Extracts a readable source location from a Lua callback function.
local function callback_source(callback)
  if callback == nil then
    return nil
  end

  local ok, info = pcall(debug.getinfo, callback, "S")
  if not ok or info == nil or info.source == nil then
    return nil
  end

  local source = info.source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  else
    source = info.short_src or source
  end

  source = vim.fn.fnamemodify(source, ":~:.")

  if type(info.linedefined) == "number" and info.linedefined > 0 then
    source = source .. ":" .. info.linedefined
  end

  return source
end

--- Resolves Lua callback keymaps to file and line source text.
function M.resolve(map)
  local source = callback_source(map.callback)
  if source ~= nil then
    return source, "callback"
  end

  return nil
end

return M
