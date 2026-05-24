local keys = require("map-list.keys")

local M = {}

local function key_modes(key)
  local mode = key.mode or "n"

  if type(mode) == "string" then
    mode = { mode }
  end

  local expanded = {}

  for _, item in ipairs(mode) do
    table.insert(expanded, item)

    if item == "v" or item == "x" then
      table.insert(expanded, "v")
      table.insert(expanded, "x")
      table.insert(expanded, "s")
    end
  end

  return expanded
end

function M.context()
  local ok, lazy_config = pcall(require, "lazy.core.config")
  if not ok then
    return {}
  end

  local sources = {}

  for plugin_name, plugin in pairs(lazy_config.plugins) do
    for _, key in ipairs(plugin.keys or {}) do
      local lhs = key[1]
      if type(lhs) == "string" then
        local normalized_lhs = keys.normalize_lhs(lhs)

        for _, mode in ipairs(key_modes(key)) do
          sources[mode .. "\0" .. normalized_lhs] = plugin.name or plugin_name
        end
      end
    end
  end

  return sources
end

function M.resolve(map, mode, context)
  local plugin = context[mode .. "\0" .. (map.lhs or "")]
  if plugin ~= nil then
    return plugin, "plugin"
  end

  return nil
end

return M
