# map-list.nvim
A compact, color-grouped keymap listing for Neovim.

`map-list.nvim` provides `:Map [filter]`, a one-line-per-mapping alternative to
the built-in `:map` output. It shows mode, lhs, description, and source in a
scratch buffer that can be searched normally.

![map-list.nvim screenshot](assets/screenshot.png)

## Features
- Compact one-line keymap rows.
- `:map <leader>`-style filtering.
- `<leader>` and `<localleader>` are dimmed for scanability.
- Buffer-local maps use Neovim's `@` marker on the mode.
- lazy.nvim key specs show the owning plugin name when available.
- Lua callbacks fall back to trimmed `file:line` source references.
- Plugin-owned rows are color-grouped using colors derived from the active
  colorscheme. *(color grouping algorithm inspired by [blame.nvim])*

## Installation
With lazy.nvim:
```lua
{
	"cmtonkinson/map-list.nvim",
}
```

The plugin only creates the `:Map` user command. If you want a keybind, you can
add it. I have mine mapped to `<leader>ml`:
```lua
vim.keymap.set("n", "<leader>ml", "<cmd>Map <lt>leader><CR>", {
	desc = "List leader keymaps",
})
```

## Usage
```vim
:Map
:Map <leader>
:Map rename
```

## Configuration
Defaults:
```lua
require("map-list").setup({
	command = "Map",
	source_providers = { "lazy", "callback", "rhs" },
	color = true,
	output = "buffer",
	window_command = "botright new",
	buffer_name = "Keymaps",
	include_buffer_local = true,
	buffer_local_marker = "@",
	modes = { "n", "v", "x", "s", "o", "i", "c", "t" },
	colors = {
		min_normal_distance = 45,
		min_comment_distance = 35,
		min_background_contrast = 2.0,
	},
})
```

Options:

| Name                             | Default                                      | Description                                                                                                               |
|----------------------------------|----------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| `command`                        | `"Map"`                                      | User command name. The default creates `:Map [filter]`; set this to rename the command, such as `"Keymaps"`.              |
| `source_providers`               | `{ "lazy", "callback", "rhs" }`              | Ordered strategies for the source column. The first provider that returns a source wins.                                  |
| `color`                          | `true`                                       | Add highlight groups/extmarks for plugin source groups, callback sources, and leader text.                                |
| `output`                         | `"buffer"`                                   | Render target. Use `"buffer"` for the scratch buffer or `"messages"` for command-line message output similar to `:map`.   |
| `window_command`                 | `"botright new"`                             | Command used to open the scratch buffer when `output = "buffer"`.                                                         |
| `buffer_name`                    | `"Keymaps"`                                  | Scratch buffer name.                                                                                                      |
| `include_buffer_local`           | `true`                                       | Include mappings local to the current buffer.                                                                             |
| `buffer_local_marker`            | `"@"`                                        | Suffix added to the mode label for buffer-local mappings.                                                                 |
| `modes`                          | `{ "n", "v", "x", "s", "o", "i", "c", "t" }` | Ordered modes to collect. Entries can be mode strings such as `"n"`, or tables such as `{ key = "n", label = "normal" }`. |
| `colors.min_normal_distance`     | `45`                                         | Minimum RGB distance between a plugin color and the active `Normal` foreground.                                           |
| `colors.min_comment_distance`    | `35`                                         | Minimum RGB distance between a plugin color and the active `Comment` foreground.                                          |
| `colors.min_background_contrast` | `2.0`                                        | Minimum contrast ratio between a plugin color and the active `Normal` background.                                         |

Built-in source providers:

| Name       | Description                                  |
|------------|----------------------------------------------|
| `lazy`     | Optional lazy.nvim plugin-name lookup.       |
| `callback` | Lua callback `file:line` via debug metadata. |
| `rhs`      | Command/string RHS fallback.                 |

Custom source providers can be functions:
```lua
require("map-list").setup({
	source_providers = {
		function(map, mode, context)
			return nil
		end,
		"lazy",
		"callback",
		"rhs",
	},
})
```

Provider functions should return `source, source_kind`. Use `source_kind =
"plugin"` to color-group rows by that source.

## Testing
Run the headless test suite from the repository root:
```sh
make test
```


[blame.nvim]: https://github.com/FabijanZulj/blame.nvim
