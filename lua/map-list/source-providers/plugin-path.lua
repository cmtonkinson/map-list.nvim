local M = {}

--- Converts a path to an absolute directory path with a trailing slash.
local function normalize_path(path)
  if path == nil or path == "" then
    return nil
  end

  path = vim.fn.fnamemodify(path, ":p")

  -- The trailing slash makes prefix checks directory-boundary aware, so
  -- /foo/plugin does not accidentally match /foo/plugin-extra/file.lua.
  return path:gsub("/+$", "") .. "/"
end

--- Extracts an absolute source path from a Lua callback.
local function source_path(callback)
  if callback == nil then
    return nil
  end

  local ok, info = pcall(debug.getinfo, callback, "S")
  if not ok or info == nil or info.source == nil then
    return nil
  end

  local source = info.source
  if source:sub(1, 1) ~= "@" then
    -- String-loaded callbacks do not have a stable filesystem path, so they
    -- cannot prove package-manager ownership.
    return nil
  end

  return vim.fn.fnamemodify(source:sub(2), ":p")
end

--- Finds the plugin whose directory contains a source path.
local function plugin_for_path(path, context)
  if path == nil then
    return nil
  end

  path = vim.fn.fnamemodify(path, ":p")

  for _, plugin in ipairs(context.plugins or {}) do
    if path:sub(1, #plugin.dir) == plugin.dir then
      return plugin.name
    end
  end

  return nil
end

--- Looks up the script path for a script-local command definition.
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

--- Reads a file defensively, returning no lines if it cannot be read.
local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if ok then
    return lines
  end

  return {}
end

--- Adds a command-to-plugin mapping if the command name is valid.
local function add_command(commands, command, plugin)
  if command ~= nil and command:match("^[A-Z][A-Za-z0-9_]*$") then
    -- Keep the first owner: command names are global, and the loaded runtime
    -- command index later provides the best available override signal.
    commands[command] = commands[command] or plugin
  end
end

--- Adds a <Plug> mapping-to-plugin entry.
local function add_plug_map(plug_maps, plug_map, plugin)
  if plug_map ~= nil then
    plug_maps[plug_map] = plug_maps[plug_map] or plugin
  end
end

--- Extracts a user command name from a Vimscript command definition line.
local function command_from_vim_line(line)
  local command = line:match("[Cc]ommand!?%s+(.+)")
  if command == nil then
    return nil
  end

  for token in command:gmatch("%S+") do
    if token:match("^[A-Z][A-Za-z0-9_]*$") then
      -- User commands must start uppercase, which lets us skip command!
      -- attributes like -bang, -range, and -complete without a full parser.
      return token
    end
  end

  return nil
end

--- Indexes Lua command and <Plug> declarations from one source line.
local function index_lua_line(line, plugin, commands, plug_maps)
  for _, command in
    line:gmatch("n?vim_create_user_command%(%s*(['\"])([A-Z][A-Za-z0-9_]*)%1")
  do
    add_command(commands, command, plugin)
  end

  for _, command in
    line:gmatch("create_user_command%(%s*(['\"])([A-Z][A-Za-z0-9_]*)%1")
  do
    add_command(commands, command, plugin)
  end

  for plug_map in line:gmatch("<Plug>%b()") do
    add_plug_map(plug_maps, plug_map, plugin)
  end
end

--- Indexes Vimscript command and <Plug> declarations from one source line.
local function index_vim_line(line, plugin, commands, plug_maps)
  add_command(commands, command_from_vim_line(line), plugin)

  for plug_map in line:gmatch("<Plug>%b()") do
    add_plug_map(plug_maps, plug_map, plugin)
  end
end

--- Indexes plugin ownership hints from one Lua or Vimscript file.
local function index_file(path, plugin, commands, plug_maps)
  for _, line in ipairs(read_lines(path)) do
    -- This intentionally indexes only common declaration forms. It is a
    -- conservative hint layer; runtime command metadata is checked afterward.
    if path:match("%.lua$") then
      index_lua_line(line, plugin, commands, plug_maps)
    elseif path:match("%.vim$") then
      index_vim_line(line, plugin, commands, plug_maps)
    end
  end
end

--- Indexes commands already loaded in Neovim back to plugin paths.
local function index_runtime_commands(context)
  for name, command in pairs(vim.api.nvim_get_commands({})) do
    local plugin = plugin_for_path(source_path(command.callback), context)

    if plugin == nil then
      -- Vimscript commands expose a script id instead of a Lua callback, so
      -- scriptinfo is the only reliable loaded-runtime path back to a plugin.
      plugin = plugin_for_path(script_path(command.script_id), context)
    end

    add_command(context.commands, name, plugin)
  end
end

--- Lists Lua and Vimscript files likely to declare plugin commands or maps.
local function plugin_files(dir)
  local files = {}

  for _, pattern in ipairs({ "plugin/**/*", "lua/**/*" }) do
    -- Package managers do not expose a universal keymap ownership registry, so
    -- we inspect the conventional plugin entrypoints and Lua modules instead.
    for _, path in ipairs(vim.fn.globpath(dir, pattern, false, true)) do
      if path:match("%.lua$") or path:match("%.vim$") then
        table.insert(files, path)
      end
    end
  end

  return files
end

--- Extracts the Ex command name from a string rhs.
local function parse_rhs_command(rhs)
  if rhs == nil then
    return nil
  end

  rhs = rhs:gsub("^%s+", "")
  rhs = rhs:gsub("^<Cmd>", ":", 1)
  rhs = rhs:gsub("^<cmd>", ":", 1)

  if rhs:sub(1, 1) ~= ":" then
    -- Non-command rhs values are left to <Plug> matching or the final rhs
    -- fallback; treating arbitrary text as a command would create false hits.
    return nil
  end

  local command = rhs:match("^:%s*([A-Z][A-Za-z0-9_]*)")
  if command ~= nil then
    return command
  end

  return nil
end

--- Extracts the leading <Plug> mapping from a string rhs.
local function parse_rhs_plug_map(rhs)
  if rhs == nil then
    return nil
  end

  return rhs:match("^(<Plug>%b())")
end

--- Deduplicates plugin directories and orders them most-specific-first so
--- prefix matching follows the longest-prefix rule when one plugin dir is
--- nested inside another (e.g. a dev plugin whose dir contains the lazy
--- install root for the other plugins).
local function dedupe_plugins(plugins)
  local result = {}
  local seen = {}

  for _, plugin in ipairs(plugins) do
    local dir = normalize_path(plugin.dir)
    if dir ~= nil and not seen[dir] then
      table.insert(result, {
        name = plugin.name,
        dir = dir,
      })
      seen[dir] = true
    end
  end

  table.sort(result, function(a, b)
    return #a.dir > #b.dir
  end)

  return result
end

--- Builds path, command, and <Plug> ownership indexes for plugins.
function M.context(plugins)
  local context = {
    plugins = dedupe_plugins(plugins or {}),
    commands = {},
    plug_maps = {},
  }

  for _, plugin in ipairs(context.plugins) do
    for _, path in ipairs(plugin_files(plugin.dir)) do
      index_file(path, plugin.name, context.commands, context.plug_maps)
    end
  end

  index_runtime_commands(context)

  return context
end

--- Resolves a keymap to an owning plugin using path and rhs indexes.
function M.resolve(map, context)
  context = context or {}
  context.commands = context.commands or {}
  context.plug_maps = context.plug_maps or {}

  -- Callback source paths are strongest because they point directly at the
  -- function body that Neovim will invoke for the mapping.
  local plugin = plugin_for_path(source_path(map.callback), context)
  if plugin ~= nil then
    return plugin, "plugin"
  end

  plugin = context.commands[parse_rhs_command(map.rhs)]
  if plugin ~= nil then
    return plugin, "plugin"
  end

  plugin = context.plug_maps[parse_rhs_plug_map(map.rhs)]
  if plugin ~= nil then
    return plugin, "plugin"
  end

  return nil
end

return M
