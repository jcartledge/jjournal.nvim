# AGENTS.md

Small daily-journaling Neovim plugin written in Lua. `CLAUDE.md` is the authoritative instruction file and is loaded automatically — read it before working; its "Testing" and "Before committing" sections govern all changes here. This file only records the facts most likely to trip up a fresh session.

## Workflow: story discipline

Every code or process change must be tied to a user story in `spec/doing/` (at most one there at a time). If no story covers the change, create one in `spec/backlog/` (use the template in CLAUDE.md), move it to `spec/doing/`, then implement, then move it to `spec/done/`. Planning new backlog stories is exempt; editing CLAUDE.md is exempt.

## Commands

- Install test deps (one-time): `luarocks test --tree=.rocks` — installs busted/luacov/luafilesystem into the local `.rocks` tree (gitignored).
- Full suite: `./tests/scripts/run.sh` — runs busted headless inside real Neovim (`nvim -l tests/scripts/run.lua tests/`), then prints a coverage summary. Aim for 100%; check `luacov.report.out` for uncovered lines.
- Single describe block: `nvim -l tests/scripts/run.lua tests/ --filter="<name>"`. Flags pass through the harness to busted; use the `--filter` form (the `-p` flag matches filenames, not test names).

## Testing conventions

Tests run against real headless Neovim, not a Lua-only stub. Never call `luassert.stub` directly — all mocking goes through `setup_test` (`tests/support/setup_test.lua`), which installs the requested mocks, calls `jjournal.setup()`, runs your test body, and always cleans up (even on assertion failure). Assert observable behavior, not that jjournal's own functions were called; `was_called`/`was_called_with` is only for the Neovim boundary (`vim.cmd`, `vim.fn.*`, `vim.api.*`, `vim.notify`). Any value Neovim itself parses (autocmd patterns, `vim.fn.glob` patterns, `strftime` format strings) needs at least one real, unmocked test with real files. Avoid busted lifecycle hooks (`before_each`, `after_each`, etc.) — reach for helpers that wrap `setup_test` instead. Specs live in `tests/jjournal_spec.lua`, one `describe` block per public function.

## Layout

- `lua/jjournal/init.lua` — config, public API, and all Neovim wiring (mappings, autocmds); `path.lua` — pure path-template helpers; `dates.lua` — date/navigation math; `search.lua` — pluggable backlog search.
- `doc/jjournal.txt` is the user-facing reference (`:help jjournal`); keep it and `README.md` current with code changes.
- `spec/` tracks user stories as they move `backlog -> todo -> doing -> done`.