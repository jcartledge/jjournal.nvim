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

Any journal buffer you haven't edited is closed automatically once you navigate away from it (no file written if it was never saved, no data lost if it was already on disk) — so browsing around doesn't leave a trail of open buffers behind. Editing a buffer keeps it around for good. To keep an unedited buffer open on purpose, `<leader>jp` pins it; pressing it again unpins, whether it was pinned that way or by editing.

`setup()` validates `base_dir`: it errors immediately if `base_dir` already exists as a file rather than a directory, and warns (without disabling the plugin) if it looks unwritable.

See `:help jjournal` for the full config reference, all default mappings, and how to customize backlog search.

**Upgrading from a flat layout:** `file_path` used to default to the flat `"%Y-%m-%d.md"`; it now defaults to nested `"%Y/%m/%Y-%m-%d.md"`. If you have existing entries in the old flat layout, either set `file_path = "%Y-%m-%d.md"` explicitly to keep them where they are, or move your existing files to match the new layout yourself (e.g. with `zmv` in zsh) before upgrading.

## Buffer status

Every buffer jjournal manages is tagged with buffer-local variables, so any statusline plugin can show at a glance what it's looking at without depending on jjournal's Lua API at all:

- `vim.b.jjournal_entry` (boolean) — `true` if jjournal manages this buffer.
- `vim.b.jjournal_date` (string) — the entry's `YYYY-MM-DD` date.
- `vim.b.jjournal_pinned` (boolean) — `true` if the buffer is protected from auto-cleanup (edited, or explicitly pinned via `<leader>jp`); unset otherwise. Since editing already pins a buffer permanently, pinned is where most buffers you actually engage with end up — the recipes below surface the *unpinned* state instead (a 👁 "just peeking, will vanish if left untouched" marker), since that's the less common, more actionable one to flag.

`jjournal.pin_buffer()` (bound to `<leader>jp` by default) also fires a `User JjournalPinned` autocmd and calls `:redrawstatus` immediately after setting `vim.b.jjournal_pinned`. `:redrawstatus` is enough on its own for any statusline that reads these variables fresh on every redraw (which is the common case — see the Heirline recipe below, which needs nothing extra). `User JjournalPinned` exists for the less common case: a framework that caches its own rendered output and only refreshes on specific events it already knows about (lualine does this) needs an explicit hook into that event to notice the change, since pinning isn't one of the events it was built to expect.

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
          if not vim.b[0].jjournal_pinned then text = text .. " 👁" end
          return status.utils.stylize(text, { padding = { left = 1, right = 1 } })
        end,
      },
      surround = { separator = "left" },
    }))
  end,
}
```

This component has no `update` field, so Heirline never caches its rendered text — it recomputes `condition`/`provider` fresh on every redraw, meaning `pin_buffer()`'s `:redrawstatus` call is all it needs. (Heirline only caches a component's output across redraws when its own `update` field is set; adding one to squeeze out a little performance would also need `User JjournalPinned` in that event list, or the cache would go stale exactly like this bug did originally — but for a component this cheap, it isn't worth the complexity.)

### Tabline / bufferline

To show which open buffers are still just a peek (unpinned, will vanish if left untouched) across every open buffer at once (useful once you have several journal entries open in different splits, where a shared statusline can only describe the current one), add the same marker to your tabline. AstroNvim's default tabline (`astronvim/plugins/heirline.lua`) already renders one entry per open buffer via:

```lua
status.heirline.make_buflist(status.component.tabline_file_info())
```

Don't insert a *second* `make_buflist(...)` into `opts.tabline` alongside it — that renders a whole duplicate row of buffer tabs. Instead, extend the `tabline_file_info()` call with an extra child, the same way `component.builder` accepts one for the statusline recipe above:

```lua
-- lua/plugins/heirline.lua
return {
  "rebelot/heirline.nvim",
  opts = function(_, opts)
    local status = require("astroui.status")

    -- Index 2 is AstroNvim's own buffer-tabs entry as of this writing
    -- (astronvim/plugins/heirline.lua's `tabline` list); adjust the
    -- index if your own opts.tabline layout differs.
    opts.tabline[2] = status.heirline.make_buflist(status.component.tabline_file_info({
      [9] = {
        -- self.bufnr, not vim.b[0]: each buffer in the tabline renders
        -- once per open buffer, most of which aren't the current one.
        condition = function(self) return not vim.b[self.bufnr].jjournal_pinned end,
        provider = " 👁",
      },
    }))
  end,
}
```

`status.component.tabline_file_info(opts)` threads `opts` through AstroUI's `setup_providers`, which only touches the numeric indices belonging to its own named providers (file icon, filename, close button, etc.) and otherwise passes `opts` straight through to the underlying `component.builder` — so an extra `opts[9]` survives as an additional child appended after the built-in ones, without disturbing the filename/icon/close-button already there.

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
