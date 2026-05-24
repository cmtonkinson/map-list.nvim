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
  colorscheme. *(color grouping inspired by [blame.nvim])*

## Installation
With lazy.nvim:
```lua
{
	"cmtonkinson/map-list.nvim",
}
```

The plugin creates `:Map` but does not add keymaps by default. I use:
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

Rows are sorted by lhs with case-insensitive ordering where lowercase comes
before uppercase for the same letter.

## Configuration
Defaults:
```lua
require("map-list").setup({
	command = "Map",
	source_providers = { "lazy", "callback", "rhs" },
	colors = {
		min_normal_distance = 45,
		min_comment_distance = 35,
		min_background_contrast = 2.0,
	},
})
```

Source providers are tried in order:
- `lazy`: optional lazy.nvim plugin-name lookup.
- `callback`: Lua callback `file:line` via debug metadata.
- `rhs`: command/string RHS fallback.

Options:
- `command`: name of the user command to create. The default is `Map`, so the
  command is available as `:Map [filter]`. Set this if you want a different
  command name, such as `Keymaps`.
- `source_providers`: ordered list of strategies used to fill the source
  column. The first provider that returns a source wins. Reordering this list
  changes source precedence; removing a provider disables that fallback.
- `colors.min_normal_distance`: minimum RGB distance between a plugin color and
  the active `Normal` foreground. Increase this if plugin colors look too much
  like ordinary text.
- `colors.min_comment_distance`: minimum RGB distance between a plugin color and
  the active `Comment` foreground. Increase this if plugin colors look too dim
  or too similar to `<leader>` / callback source text.
- `colors.min_background_contrast`: minimum contrast ratio between a plugin
  color and the active `Normal` background. Increase this if plugin colors are
  hard to read; decrease it if your theme has a small palette and too few colors
  are being selected.

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

Provider functions should return `source, source_kind`. Use
`source_kind = "plugin"` to color-group rows by that source.

## Testing
Run the headless test suite from the repository root:
```sh
make test
```


[blame.nvim]: https://github.com/FabijanZulj/blame.nvim
