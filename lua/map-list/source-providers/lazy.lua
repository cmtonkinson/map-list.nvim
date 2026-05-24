local keys = require("map-list.keys")
local plugin_path = require("map-list.source-providers.plugin-path")

local M = {}

--- Expands a lazy.nvim key spec mode into Neovim map modes.
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

--- Builds lazy.nvim key-spec and plugin-path lookup context.
function M.context()
  local ok, lazy_config = pcall(require, "lazy.core.config")
  if not ok then
    return {}
  end

  local sources = {
    keys = {},
    path = {},
  }
  local plugins = {}

  for plugin_name, plugin in pairs(lazy_config.plugins) do
    table.insert(plugins, {
      name = plugin.name or plugin_name,
      dir = plugin.dir,
    })

    for _, key in ipairs(plugin.keys or {}) do
      local lhs = key[1]
      if type(lhs) == "string" then
        local normalized_lhs = keys.normalize_lhs(lhs)

        for _, mode in ipairs(key_modes(key)) do
          -- lazy.nvim key specs are the strongest signal because they encode
          -- the user's intent before a mapping is materialized in Neovim.
          sources.keys[mode .. "\0" .. normalized_lhs] = plugin.name
            or plugin_name
        end
      end
    end
  end

  sources.path = plugin_path.context(plugins)

  return sources
end

--- Resolves a keymap to its lazy.nvim owning plugin when possible.
function M.resolve(map, mode, context)
  local plugin = context.keys and context.keys[mode .. "\0" .. (map.lhs or "")]
  if plugin ~= nil then
    return plugin, "plugin"
  end

  -- Some mappings are created by plugin code instead of lazy key specs, so
  -- fall back to the same path/command inference used by other managers.
  return plugin_path.resolve(map, context.path or {})
end

return M
