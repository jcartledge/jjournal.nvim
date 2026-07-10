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
