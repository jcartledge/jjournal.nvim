# jjournal.nvim

A minimal daily journaling plugin for Neovim.

## Requirements

- Neovim
- [LuaRocks](https://luarocks.org/)

## Installation (as a plugin)

Point your plugin manager at this repo, then call setup:

```lua
require("jjournal").setup({
  path = "~/notes/journals/", -- default
  use_default_mappings = true,
  search = "auto", -- "auto" | "telescope" | "builtin" | function(path)
})
```

Default keymaps (when `use_default_mappings = true`): `gj`/`gJ` open today's journal (split), `[j`/`]j` and `[J`/`]J` step to the previous/next journal (split), `<leader>jj`/`<leader>jJ` prompt for a date (split), `<leader>fj` searches the journal backlog.

`search` controls what `<leader>fj` (and `execute("search")`) uses to search the backlog:

- `"auto"` (default): uses [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)'s `live_grep` if installed, otherwise falls back to a builtin `:vimgrep` search (prompts for a term, then opens the results in the quickfix list) with no warning.
- `"telescope"`: always uses telescope; warns and falls back to the builtin search if telescope isn't installed.
- `"builtin"`: always uses the builtin `:vimgrep` search, even if telescope is installed.
- a function `function(path)`: called directly with the configured journal path, for any other picker (fzf-lua, mini.pick, snacks.picker, etc.).

## Developing

Clone the repo and install test dependencies into a local `.rocks` tree:

```sh
luarocks test --tree=.rocks
```

This installs `busted`, `luacov`, `luacov-reporter-lcov`, and `luafilesystem` (see `test_dependencies` in `jjournal-dev-1.rockspec`), then runs the test command below.

## Running tests

```sh
./tests/scripts/run.sh
```

This runs the busted suite headless inside Neovim (`nvim -l tests/scripts/run.lua tests/`), then generates a coverage report and prints a summary. Coverage output is written to `luacov.report.out` (lcov format, gitignored) and `luacov.stats.out`.

Once dependencies are installed, `./tests/scripts/run.sh` is faster to iterate with than re-running `luarocks test`.

## Project structure

```
lua/jjournal/   -- plugin source
tests/          -- busted specs and test harness
spec/           -- user stories, tracked as they move backlog -> todo -> doing -> done
```

See `CLAUDE.md` for how work is planned and tracked as user stories under `spec/`.
