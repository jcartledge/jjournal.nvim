## **Story: [tech] Create parent directories when opening a journal path that doesn't exist**

**Use Case:** `open_date` calls `vim.cmd("edit " .. path)` assuming the parent directory already exists; Neovim won't create missing intermediate directories on save. This is low-risk today with a flat journal folder, but becomes a real gap once the configurable-path-template story (nested `journal/%Y/%m/%d.md`-style paths) lands, since a new year/month directory won't exist yet the first time it's needed.

### **Acceptance Criteria**

* **Given** a configured journal path whose parent directory does not exist on disk,
* **When** a journal date is opened via `open_date`,
* **Then** the parent directory is created (recursively) before the buffer is opened, so saving succeeds.
* **Given** the parent directory already exists,
* **When** a journal date is opened,
* **Then** no additional directory-creation calls are made and behavior is unchanged.

### **Busted Test Cases**

```
it("creates the parent directory before opening a date whose directory doesn't exist", function()
    -- stub vim.fn.mkdir and vim.cmd, call jjournal.open_date("2026-07-09", "edit"),
    -- assert vim.fn.mkdir was called with the parent directory and "p" before vim.cmd ran
end)

it("does not error or duplicate directory creation when the directory already exists", function()
    -- stub vim.fn.mkdir and vim.cmd, call jjournal.open_date("2026-07-09", "edit") twice,
    -- assert vim.cmd still opens the correct path both times
end)
```

## **Revision: defer directory creation to write time instead of open time**

**Use Case:** Creating the parent directory eagerly in `open_date`, before the buffer even exists, means a buffer that's opened and later discarded unsaved -- e.g. a preview auto-wiped by `register_autocmds`' cleanup autocmd (see `pin-buffers-to-exempt-from-auto-cleanup.md`), or one navigated past without editing -- can leave an empty, orphaned directory behind on disk even though no file was ever written. Verified empirically against real Vim: `:edit` on a path whose parent directory doesn't exist at all succeeds with no error (Neovim only needs the directory to exist at write time, not open time), and a `BufWritePre` autocmd that creates the parent directory just-in-time makes the subsequent write succeed. Moving directory creation from `open_date` to a `BufWritePre` autocmd -- scoped with the same pattern already shared by the other journal autocmds -- means a directory only ever comes into existence the moment a file is actually about to be written there, so an unsaved, discarded buffer never creates one to begin with. This removes the orphaned-directory problem entirely rather than cleaning it up after the fact (superseding `clean-up-orphaned-empty-directories.md`, deleted from the backlog as moot).

### **Revised Acceptance Criteria**

* **Given** a configured journal path whose parent directory does not exist on disk,
* **When** the journal date is opened via `open_date`,
* **Then** the buffer opens successfully and no directory is created yet.

* **Given** that same buffer,
* **When** it is written (`:w`) for the first time,
* **Then** its parent directory is created (recursively) just before the write, so the write succeeds.

* **Given** the parent directory already exists,
* **When** the buffer is written,
* **Then** no additional directory-creation calls are made and behavior is unchanged.

* **Given** a buffer that is opened but never written (e.g. an auto-wiped preview),
* **When** it is discarded,
* **Then** no directory was ever created for it.

### **Revised Busted Test Cases**

```
it("does not create any directory when open_date opens a buffer, only when it's later written", function()
    -- stub vim.fn.mkdir and vim.cmd, call jjournal.open_date("2026-07-09", "edit"),
    -- assert vim.fn.mkdir was NOT called
end)

it("registers a BufWritePre autocmd scoped to the same journal pattern as the other autocmds", function()
    -- mock nvim_create_autocmd, assert a BufWritePre autocmd is registered
    -- with the shared pattern
end)

it("creates the parent directory just before a real write, for a real file whose directory doesn't exist yet", function()
    -- real, unmocked test in the style of fix-autocmd-pattern-for-flat-layouts.md:
    -- real temp dir, real :edit of a nested path whose directories don't exist,
    -- real :write, assert the file and its directory now exist on disk
end)

it("does not error or duplicate directory creation when writing to a directory that already exists", function()
end)
```
