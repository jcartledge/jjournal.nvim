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

With `use_default_mappings = true` (the default), `gj` opens today's journal entry, `[jj`/`]jj` step one day at a time, `[j`/`]j` skip to the previous/next existing entry, `<leader>jj` prompts for a date, and `<leader>fj` searches the backlog. `[jj`/`]jj`/`[j`/`]j` and `<leader>jp` (pinning, below) are only mapped inside journal buffers, since they only mean something relative to an entry you're already in; `gj`/`<leader>jj`/`<leader>fj` work from anywhere as entry points into the journal.

Any journal buffer you haven't edited is closed automatically once you navigate away from it (no file written if it was never saved, no data lost if it was already on disk) — so browsing around doesn't leave a trail of open buffers behind. Editing a buffer keeps it around for good. To keep an unedited buffer open on purpose, `<leader>jp` pins it.

`setup()` validates `base_dir`: it errors immediately if `base_dir` already exists as a file rather than a directory, and warns (without disabling the plugin) if it looks unwritable.

See `:help jjournal` for the full config reference, all default mappings, and how to customize backlog search.

**Upgrading from a flat layout:** `file_path` used to default to the flat `"%Y-%m-%d.md"`; it now defaults to nested `"%Y/%m/%Y-%m-%d.md"`. If you have existing entries in the old flat layout, either set `file_path = "%Y-%m-%d.md"` explicitly to keep them where they are, or move your existing files to match the new layout yourself (e.g. with `zmv` in zsh) before upgrading.

## Buffer status

Every buffer jjournal manages is tagged with buffer-local variables, so any statusline plugin can show at a glance what it's looking at without depending on jjournal's Lua API at all:

- `vim.b.jjournal_entry` (boolean) — `true` if jjournal manages this buffer.
- `vim.b.jjournal_date` (string) — the entry's `YYYY-MM-DD` date.
- `vim.b.jjournal_pinned` (boolean) — `true` if the buffer is protected from auto-cleanup (edited, or explicitly pinned via `<leader>jp`); unset otherwise. The default (unpinned, ephemeral) state needs no indication — only the pinned exception is usually worth surfacing.

`jjournal.pin_buffer()` (bound to `<leader>jp` by default) also fires a `User JjournalPinned` autocmd and calls `:redrawstatus` immediately after setting `vim.b.jjournal_pinned`. `:redrawstatus` is enough for a statusline that reads these variables fresh on every redraw; but a framework that caches its own rendered output and only recomputes on specific autocmd events (Heirline's `update` list, see below) needs `User JjournalPinned` added to that event list, or it won't notice the change until some unrelated event happens to fire.

No UI ships with jjournal itself — wire these into whatever statusline you already use. For example, with [AstroNvim](https://astronvim.com), which uses [Heirline.nvim](https://github.com/rebelot/heirline.nvim) via `astroui.status`:

```lua
-- lua/plugins/heirline.lua
return {
  "rebelot/heirline.nvim",
  opts = function(_, opts)
    local status = require("astroui.status")

    table.insert(opts.statusline, status.component.builder({
      {
        condition = function() return vim.b[0].jjournal_entry end,
        provider = function()
          local text = vim.b[0].jjournal_date or ""
          if vim.b[0].jjournal_pinned then text = text .. " 📌" end
          return status.utils.stylize(text, { padding = { left = 1, right = 1 } })
        end,
      },
      update = { "BufEnter", "TextChanged", "TextChangedI", { "User", pattern = "JjournalPinned" } },
      surround = { separator = "left" },
    }))
  end,
}
```

For any other statusline plugin (lualine, mini.statusline, native `'statusline'`), the same three variables are all you need to read — but if that plugin also caches its rendered output rather than recomputing on every redraw (lualine does), hook its own refresh function to the `User JjournalPinned` autocmd (e.g. `vim.api.nvim_create_autocmd("User", { pattern = "JjournalPinned", callback = function() require("lualine").refresh() end })`) the same way you would for any other state change it doesn't already know about.

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

## License

MIT — see [LICENSE](LICENSE).
