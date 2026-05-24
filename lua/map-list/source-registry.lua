local callback = require("map-list.source-providers.callback")
local lazy = require("map-list.source-providers.lazy")
local rhs = require("map-list.source-providers.rhs")

local M = {}

local providers = {
  callback = callback,
  lazy = lazy,
  rhs = rhs,
}

function M.context()
  local context = {}

  for name, provider in pairs(providers) do
    if provider.context ~= nil then
      context[name] = provider.context()
    end
  end

  return context
end

function M.resolve(provider, map, mode, context)
  if type(provider) == "function" then
    return provider(map, mode, context)
  end

  if providers[provider] ~= nil then
    return providers[provider].resolve(map, mode, context[provider] or {})
  end

  return nil
end

return M
