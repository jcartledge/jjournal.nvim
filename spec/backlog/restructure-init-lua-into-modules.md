## **Story: [tech] Split init.lua into path/dates/search modules, standardize naming and comments**

**Use Case:** `lua/jjournal/init.lua` is well factored at the function level, but at ~400 lines it's sprawling and hard to hold a mental model of: five genuinely distinct concerns (path/template helpers, date-navigation math, the public action/resolution layer, backlog search, and Neovim setup/wiring) are interleaved rather than grouped, the section banners use invented, dated terminology ("ATOM 1", "THE UNIFIED EXECUTION PIPELINE") that reads as private notes-to-self and has drifted from what's actually there, and the file opens with a stale, wrong header comment (`-- lua/user/journal.lua`) left over from wherever this was originally extracted from. This is a pure internal restructuring: no user-facing behavior changes, and the existing test suite should pass unmodified as the proof of that.

### **Acceptance Criteria**

* **Given** the current single-file module,
* **When** it's restructured,
* **Then** it becomes four files: `lua/jjournal/path.lua` (pure path/template helpers: `extract_date_from_filename`, `file_path_basename`, `file_path_extension`, `expand_file_path`, `validate_file_path`, `normalize_base_dir`), `lua/jjournal/dates.lua` (date-navigation math, exposing only `get_nav_date(base_dir, direction)`; everything else it currently needs — `current_anchor_date`, `dates_from_disk`, `dates_from_buffers`, `flatten_and_sort_dates`, `all_available_dates`, `target_index`, `shift_date` — stays private to that module), `lua/jjournal/search.lua` (backlog search: `has_telescope`, `builtin_search`, `providers`, collapsed dispatch logic exposed as `run(choice, base_dir, extension)`), and `lua/jjournal/init.lua` left as a thin orchestrator: `M.config`, `M.mappings`, `M.setup`/`bind_mappings`/`register_autocmds`, and the public action layer (`prompt_for_date`, `resolve_date`, `resolve_path`, `open_date`, `execute`, `search_backlog`), each delegating into the three modules above.

* **Given** `path.lua`/`dates.lua`/`search.lua` need config values,
* **When** they're called from `init.lua`,
* **Then** every value they need (`base_dir`, `file_path`, etc.) is passed explicitly as a function parameter — no submodule reads `M.config` or requires `jjournal.init` itself, avoiding a circular require and keeping each module a pure, self-contained unit.

* **Given** `dates_from_disk`/`dates_from_buffers` currently mutate an accumulator table passed in by the caller,
* **When** they're rewritten,
* **Then** each instead returns its own fresh date set, merged by the caller via `vim.tbl_extend("force", ...)` — no shared mutable state threaded between them.

* **Given** `M.search_providers` is currently a public field on the returned module but is untested and undocumented (not listed in `doc/jjournal.txt`'s Lua API section),
* **When** search logic moves into `search.lua`,
* **Then** it becomes private to that module (`providers`) rather than staying public — a deliberate, small reduction in undocumented surface area, not an oversight.

* **Given** every interface, public and private,
* **When** it's read by `lua_ls`,
* **Then** it has a LuaCATS doc comment (`---@param`/`---@return`, plus a one-line description where the name doesn't already make the purpose obvious) — this applies uniformly across all four files, not just the public `M.*` API.

* **Given** the file's stale header comment and the "ATOM"-style section banners,
* **When** the restructuring is done,
* **Then** both are gone, per the new Comments section in `CLAUDE.md`: no file-path self-references, no decorative banners, comments explain *why* rather than restating *what*.

* **Given** the existing 62-test busted suite,
* **When** it's run against the restructured code,
* **Then** it passes completely unmodified (no test file changes needed) with coverage still at 100% — the public interface (`jjournal.config`, `.mappings`, `.setup`, `.execute`, `.resolve_date`, `.resolve_path`, `.open_date`, `.prompt_for_date`, `.search_backlog`) is unchanged, so this is the direct evidence that no behavior moved.

### **Busted Test Cases**

Not applicable in the usual test-first sense — no new behavior is being added, so there's nothing to pin down with a new failing spec first. Verification is: the existing `tests/jjournal_spec.lua` requires zero changes, `./tests/scripts/run.sh` reports all specs passing, and coverage stays at 100% across all four `lua/jjournal/*.lua` files combined.
