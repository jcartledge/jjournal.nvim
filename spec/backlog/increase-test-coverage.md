## **Story 4: Increase test coverage**

**Use Case:** The busted suite currently only exercises `resolve_date`'s date-resolution paths. Several other code paths in `lua/jjournal/init.lua` have no coverage at all (per `luacov.report.out`: `open_date`'s warn branch, `prompt_for_date`, `search_backlog`, `bind_mappings`, `register_autocmds`, and part of `setup`). You want confidence that changes to these areas won't silently break behavior.

### **Acceptance Criteria**

* **Given** the current busted suite covers only date-resolution logic,
* **When** specs are added for `open_date`, `prompt_for_date`, `search_backlog`, `bind_mappings`, and `register_autocmds`,
* **Then** the line coverage reported by `luacov` (see `./tests/scripts/run.sh` summary output) increases from its current baseline and these paths are protected by the test suite going forward.

### **Busted Test Cases**

```
it("opens the resolved date with the given command", function()
    -- stub vim.cmd, call jjournal.open_date("2026-07-09", "vsplit"),
    -- assert vim.cmd was called with "vsplit .../2026-07-09.md"
end)

it("warns and does not open anything when date_str is nil", function()
    -- stub vim.notify, call jjournal.open_date(nil),
    -- assert vim.notify was called with a WARN level message and vim.cmd was not called
end)

it("prompts for a date and invokes the callback with user input", function()
    -- stub vim.ui.input to invoke its callback with a date string,
    -- assert jjournal.prompt_for_date's callback receives that string
end)

it("does not invoke the callback when the date prompt is cancelled", function()
    -- stub vim.ui.input to invoke its callback with nil/"",
    -- assert the callback passed to jjournal.prompt_for_date is never called
end)

it("delegates backlog search to telescope's live_grep with the configured path", function()
    -- stub require("telescope.builtin").live_grep,
    -- call jjournal.search_backlog(), assert live_grep was called with search_dirs = { M.config.path }
end)

it("binds default keymaps when use_default_mappings is true", function()
    -- stub vim.keymap.set, call jjournal.setup({ use_default_mappings = true }),
    -- assert vim.keymap.set was called once per entry in jjournal.mappings
end)

it("skips keymap binding when use_default_mappings is false", function()
    -- stub vim.keymap.set, call jjournal.setup({ use_default_mappings = false }),
    -- assert vim.keymap.set was never called
end)

it("registers a BufReadPost/BufNewFile autocmd scoped to the configured journal path", function()
    -- stub vim.api.nvim_create_autocmd, call jjournal.setup({}),
    -- assert it was called with { "BufReadPost", "BufNewFile" } and a pattern matching M.config.path .. "*.md"
end)
```
