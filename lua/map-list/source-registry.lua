local callback = require("map-list.source-providers.callback")
local lazy = require("map-list.source-providers.lazy")
local packer = require("map-list.source-providers.packer")
local rhs = require("map-list.source-providers.rhs")
local vim_plug = require("map-list.source-providers.vim-plug")

local M = {}

local package_providers = {
  -- Product decision: source provider order is fixed so package-manager
  -- ownership always beats generic callback or rhs fallbacks.
  { name = "lazy", provider = lazy },
  { name = "vim-plug", provider = vim_plug },
  { name = "packer", provider = packer },
}

--- Builds reusable source-provider context for the current render pass.
function M.context()
  local context = {}

  for _, item in ipairs(package_providers) do
    local name = item.name
    local provider = item.provider

    if provider.context ~= nil then
      context[name] = provider.context()
    end
  end

  return context
end

--- Resolves a keymap source using package managers, then callback, then rhs.
function M.resolve(map, mode, context)
  for _, item in ipairs(package_providers) do
    local name = item.name
    local provider = item.provider
    local source, source_kind = provider.resolve(map, mode, context[name] or {})

    if source ~= nil then
      return source, source_kind
    end
  end

  local source, source_kind = callback.resolve(map)
  if source ~= nil then
    return source, source_kind
  end

  return rhs.resolve(map)
end

return M
