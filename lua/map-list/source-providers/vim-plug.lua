local plugin_path = require("map-list.source-providers.plugin-path")

local M = {}

function M.context()
  local plugins = {}

  for name, plug in pairs(vim.g.plugs or {}) do
    if type(plug) == "table" then
      table.insert(plugins, {
        name = name,
        dir = plug.dir,
      })
    end
  end

  return plugin_path.context(plugins)
end

function M.resolve(map, _, context)
  return plugin_path.resolve(map, context or {})
end

return M
