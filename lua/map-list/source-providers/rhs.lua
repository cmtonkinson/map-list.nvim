local M = {}

local function clean_rhs(rhs)
  if rhs == nil or rhs == "" then
    return "<Lua function>"
  end

  return rhs:gsub("\r", "<CR>"):gsub("\n", "\\n")
end

function M.resolve(map)
  return clean_rhs(map.rhs), "rhs"
end

return M
