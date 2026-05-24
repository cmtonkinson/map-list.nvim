local plugin_path = require("map-list.source-providers.plugin-path")

local M = {}

--- Reads plugin metadata exposed by packer's compiled loader.
local function packer_plugins()
  local plugins = {}

  for name, plugin in pairs(_G.packer_plugins or {}) do
    if type(plugin) == "table" then
      table.insert(plugins, {
        name = name,
        dir = plugin.path,
      })

      if
        type(plugin.url) == "string" and vim.fn.isdirectory(plugin.url) == 1
      then
        -- Local packer specs can load from the original directory while the
        -- compiled metadata also points at packer's copied start package.
        table.insert(plugins, {
          name = name,
          dir = plugin.url,
        })
      end
    end
  end

  return plugins
end

--- Falls back to discovering packer-style package directories on packpath.
local function packpath_plugins()
  local plugins = {}

  for _, packpath in ipairs(vim.opt.packpath:get()) do
    for _, kind in ipairs({ "start", "opt" }) do
      local pattern = packpath .. "/pack/*/" .. kind .. "/*"
      for _, dir in ipairs(vim.fn.glob(pattern, false, true)) do
        if vim.fn.isdirectory(dir) == 1 then
          table.insert(plugins, {
            name = vim.fn.fnamemodify(dir, ":t"),
            dir = dir,
          })
        end
      end
    end
  end

  return plugins
end

--- Builds packer plugin ownership lookup context.
function M.context()
  local plugins = packer_plugins()
  if #plugins == 0 then
    plugins = packpath_plugins()
  end

  return plugin_path.context(plugins)
end

--- Resolves a keymap to its packer owning plugin when possible.
function M.resolve(map, _, context)
  return plugin_path.resolve(map, context or {})
end

return M
