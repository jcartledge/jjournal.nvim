## **Story: [bugfix] Fix autocmd pattern so it matches flat (non-nested) journal layouts**

**Use Case:** `register_autocmds` builds a single shared pattern, `<base_dir>/**/*<ext>`, used by all three of its autocmds: journal-status/buffer-local-mapping tagging (`BufReadPost`/`BufNewFile`), pin-on-edit (`TextChanged`/`TextChangedI`), and unpinned-buffer cleanup (`BufWinLeave`). Neovim's `autocmd-pattern` `**` wildcard requires at least one subdirectory between `<base_dir>` and the filename to match -- it silently does not match a file that lives directly inside `<base_dir>` with zero subdirectories. `file_path = "%Y-%m-%d.md"` (a flat, non-nested layout) is explicitly documented as a supported configuration, but for anyone using it, none of these three autocmds ever fire: journal buffers never get tagged, pinning-on-edit never happens, and unpinned buffers are never cleaned up. Navigation (`step`/`skip`) is unaffected, since `dates_from_disk` uses `vim.fn.glob`, which doesn't share this quirk. Verified empirically against real headless Neovim that `<base_dir>/**<ext>` (dropping the redundant `/*`) matches both flat and nested layouts correctly.

### **Acceptance Criteria**

* **Given** `config.file_path` is a flat, non-nested template (e.g. `"%Y-%m-%d.md"`),
* **When** a journal buffer for that layout is opened, edited, and left,
* **Then** it is tagged with `journal_status` on open, gets `jjournal_pinned` set once edited, and is cleaned up on `BufWinLeave` if never edited -- the same as it already works for nested layouts.

* **Given** `config.file_path` is a nested template (e.g. the default `"%Y/%m/%Y-%m-%d.md"`),
* **When** the same sequence happens,
* **Then** behavior is unchanged from before this fix (no regression).

### **Busted Test Cases**

```
it("tags a real buffer for a flat (non-nested) file_path layout via a real, unmocked autocmd", function()
    -- Deviates from the mocking-only convention deliberately: the whole
    -- point is to exercise real Neovim autocmd-pattern matching, which a
    -- mocked nvim_create_autocmd can never do. Writes a real file to a
    -- real temp dir, calls jjournal.setup() unmocked, :edit's the file for
    -- real, and asserts vim.b[buf].journal_status actually got set.
end)

it("still tags a real buffer for a nested file_path layout via a real, unmocked autocmd", function()
    -- Companion regression test alongside the flat-layout one above, using
    -- the same real-file/real-autocmd approach, to pin down that the fix
    -- doesn't break the previously-working nested case.
end)
```
