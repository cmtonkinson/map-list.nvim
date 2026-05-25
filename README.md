# map-list.nvim
A compact, color-grouped keymap listing for Neovim.

`map-list.nvim` provides `:Map [filter]`, a one-line-per-mapping alternative to
the built-in `:map` output. It shows mode, lhs, description, and source in a
scratch buffer that can be searched normally.

With lazy.nvim:
```lua
{
	"cmtonkinson/map-list.nvim",
	opts = {},
}
```

![map-list.nvim screenshot](assets/screenshot.png)

------------------------------------------------------------------------
## Features
- Compact one-line keymap rows.
- `:map`-style filtering (e.g. `:Map <leader>`).
- `<leader>` and `<localleader>` are dimmed for scanability.
- Buffer-local maps use Neovim's `@` marker on the mode.
- Supported plugin managers show the owning plugin name when available.
- Lua callbacks fall back to trimmed `file:line` source references.
- Plugin-owned rows are color-grouped using colors derived from the active
  colorscheme. *(color grouping algorithm inspired by [blame.nvim])*

------------------------------------------------------------------------
## Requirements
- Neovim 0.7+ (for `nvim_create_user_command`).
- No other runtime dependencies. Plugin-manager detection is opportunistic and
  works with **lazy.nvim**, **vim-plug**, or **packer** when present.

------------------------------------------------------------------------
## Installation
Calling `setup()` is optional — the plugin registers the `:Map` command on load
using defaults. Pass `opts` only to override them.

If you want a keybind, you can add it. I have mine mapped to `<leader>ml`:
```lua
vim.keymap.set("n", "<leader>ml", "<cmd>Map <lt>leader><CR>", {
	desc = "List leader keymaps",
})
```

*(Note: The `<lt>` escapes the literal `<` so the mapping passes the text
`<leader>` to `:Map` rather than expanding it to your actual leader key.)*

------------------------------------------------------------------------
## Usage
```vim
:Map
:Map <leader>
:Map rename
```

### Default filter
The filter is case-insensitive and matches in this order:
- If the filter contains a space, it matches as a prefix against the raw lhs
  (so `:Map <leader> f` lists mappings whose lhs begins with `<leader> f`).
- Otherwise it matches as a substring against the lhs.
- If neither lhs form matches, the filter is also tried as a substring against
  the mapping's description and right-hand side.

### Plugin filter (`@`)
The `@` prefix filters by *which plugin a mapping targets*, regardless of how
the RHS is wired:
- `:Map @` — every mapping attributable to a plugin (any of: registered by the
  plugin, RHS uses a user command the plugin defines, RHS calls a Lua module
  owned by the plugin).
- `:Map @<name>` — every mapping targeting a plugin whose name contains
  `<name>`. The match is a case-insensitive substring against the plugin name,
  so common `nvim-` prefixes and `.nvim` suffixes are absorbed automatically:
  `@telescope` matches `telescope.nvim`, and `@git` matches `gitsigns.nvim`,
  `vim-fugitive`, `git-blame.nvim`, and any other installed plugin with `git`
  in its name. Targeting includes both `<Cmd>X<CR>`-style user-command RHSs and
  `require("...").*` Lua-callback RHSs owned by the plugin.

### Ex-command filter (`:`)
The `:` prefix filters by *which Ex command a mapping's RHS invokes*. This is a
narrower view than `@` — it only catches mappings whose RHS is `<Cmd>X<CR>` or
`:X<CR>`, not Lua callbacks. The match is a **case-sensitive** substring
against the Ex command name, matching Vim's own treatment of Ex command names
(built-ins are lowercase, user commands are conventionally capitalized):
- `:Map :` — every mapping whose RHS invokes any Ex command (built-in or user).
- `:Map :Telescope` — only mappings whose RHS invokes the `:Telescope` user
  command. A `require("telescope.builtin").*` callback mapped to the same lhs
  would *not* match this filter, but would match `:Map @telescope`. `:Map
  :telescope` (lowercase) would not match either.
- `:Map :nohl` — matches `:nohlsearch`, but `:Map :NoHl` would not.

Use `@name` to answer "where am I using plugin X at all?" and `:Name` to answer
"where am I invoking the `:Name` command specifically?" Usually, you probably
want `@name`.

------------------------------------------------------------------------
## Configuration
Defaults:
```lua
require("map-list").setup({
	command = "Map",
	color = true,
	output = "buffer",
	window_command = "botright new",
	buffer_name = "Keymaps",
	include_buffer_local = true,
	buffer_local_marker = "@",
	collapse_modes = true,
	show_rhs_source = true,
	modes = { "n", "v", "x", "s", "o", "i", "c", "t" },
	colors = {
		min_normal_distance = 45,
		min_comment_distance = 35,
		min_background_contrast = 2.0,
	},
})
```

Options:

| Name                             | Default                                      | Description                                                                                                           |
|----------------------------------|----------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| `command`                        | `"Map"`                                      | User command name. The default creates `:Map [filter]`; set this to rename the command, such as `"Keymaps"`.          |
| `color`                          | `true`                                       | Add highlight groups/extmarks for plugin source groups, callback sources, and leader text.                            |
| `output`                         | `"buffer"`                                   | Render target. Use `"buffer"` for the scratch buffer or `"messages"` to print to the command-line area like `:map`.   |
| `window_command`                 | `"botright new"`                             | Command used to open the scratch buffer when `output = "buffer"`.                                                     |
| `buffer_name`                    | `"Keymaps"`                                  | Scratch buffer name.                                                                                                  |
| `include_buffer_local`           | `true`                                       | Include mappings local to the current buffer.                                                                         |
| `buffer_local_marker`            | `"@"`                                        | Suffix added to the mode label for buffer-local mappings.                                                             |
| `collapse_modes`                 | `true`                                       | Collapse identical mappings across modes into one row with a combined mode label.                                     |
| `show_rhs_source`                | `true`                                       | Append a dimmed `file:line` reference after rhs fallback sources when Neovim exposes script metadata for the mapping. |
| `modes`                          | `{ "n", "v", "x", "s", "o", "i", "c", "t" }` | Ordered modes to collect. See below for entry shape.                                                                  |
| `colors.min_normal_distance`     | `45`                                         | Minimum RGB distance between a plugin color and the active `Normal` foreground.                                       |
| `colors.min_comment_distance`    | `35`                                         | Minimum RGB distance between a plugin color and the active `Comment` foreground.                                      |
| `colors.min_background_contrast` | `2.0`                                        | Minimum contrast ratio between a plugin color and the active `Normal` background.                                     |

Each `modes` entry can be either a bare mode string or a table with an explicit
display label:
```lua
modes = {
	"n",
	{ key = "v", label = "visual" },
}
```

------------------------------------------------------------------------
## Source resolution
For each mapping, the source column is filled by trying providers in a fixed
order and using the first one that produces a value.

| Order | Source          | Description                                                    |
|-------|-----------------|----------------------------------------------------------------|
| 1     | Plugin manager  | Auto-detected lazy.nvim, vim-plug, or packer plugin ownership. |
| 2     | Lua callback    | Lua callback `file:line` via debug metadata.                   |
| 3     | Right-hand side | Command/string RHS fallback.                                   |

------------------------------------------------------------------------
## Testing
Run the headless test suite from the repository root:
```sh
make test
```

For manual testing against real plugin managers, isolated profile entrypoint
scripts are available. Each launcher starts Neovim with its own XDG
config/data/state/cache directories and installs a small shared plugin set with
defined keybindings so you can verify `:Map <leader>` with themed source
grouping:
```sh
./manual/lazy/start
./manual/vim-plug/start
./manual/packer/start
```


[blame.nvim]: https://github.com/FabijanZulj/blame.nvim
