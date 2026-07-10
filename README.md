# jjournal.nvim

A minimal daily journaling plugin for Neovim.

## Installation

Requires Neovim. Point your plugin manager at this repo, then call setup:

```lua
require("jjournal").setup({
  base_dir = "~/notes/journals/", -- default
  file_path = "%Y/%m/%Y-%m-%d.md", -- default; nests by year/month. %Y/%m/%d/%D placeholders available
  use_default_mappings = true,
  search = "auto", -- "auto" | "telescope" | "builtin" | function(base_dir)
})
```

With `use_default_mappings = true` (the default), `gj` opens today's journal entry, `[j`/`]j` step to the previous/next entry, `<leader>jj` prompts for a date, and `<leader>fj` searches the backlog.

See `:help jjournal` for the full config reference, all default mappings, and how to customize backlog search.

**Upgrading from a flat layout:** `file_path` used to default to the flat `"%Y-%m-%d.md"`; it now defaults to nested `"%Y/%m/%Y-%m-%d.md"`. If you have existing entries in the old flat layout, either set `file_path = "%Y-%m-%d.md"` explicitly to keep them where they are, or move your existing files to match the new layout yourself (e.g. with `zmv` in zsh) before upgrading.

## Developing

Requires [LuaRocks](https://luarocks.org/) in addition to Neovim. Clone the repo and install test dependencies into a local `.rocks` tree:

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
doc/            -- vimdoc (:help jjournal); user-facing reference lives here, not in this README
tests/          -- busted specs and test harness
spec/           -- user stories, tracked as they move backlog -> todo -> doing -> done
```

See `CLAUDE.md` for how work is planned and tracked as user stories under `spec/`.
