## **Story: Auto-clean unedited preview buffers for not-yet-existing entries**

**Use Case:** Stepping through today/future dates (per `skip-empty-days-past-sequential-future-navigation`) opens a real buffer for each date you stop at, even when nothing exists on disk for it yet. Walking forward across several days to plan ahead leaves a trail of unedited, blank buffers cluttering `:ls` unless something cleans them up. An unedited buffer for a date that doesn't exist yet should behave like a disposable preview: gone the moment you navigate away, but a normal, persistent buffer the moment you actually type into it.

This directly follows from `skip-empty-days-past-sequential-future-navigation` (done): before it, stepping into an empty future date failed silently (nothing opened), so this problem couldn't arise. Now that it opens a real buffer every time, this is the cleanup half of the same feature.

Preview status is decided purely by whether the resolved file already exists on disk at the moment it's opened — not by which mapping got you there. So `gj` or `<leader>jj` landing on a not-yet-existing date is a preview too, the same as `]j`/`[j`; today included, no special-casing.

### **Acceptance Criteria**

* **Given** `open_date` opens a date whose file does not already exist on disk,
* **When** the buffer is created,
* **Then** it's flagged as a preview buffer (`vim.b[buf].jjournal_preview = true`).

* **Given** `open_date` opens a date whose file already exists,
* **When** the buffer is opened,
* **Then** it is not flagged as a preview — normal persistent behavior, unchanged.

* **Given** a buffer flagged as a preview that has never been modified,
* **When** it stops being displayed in any window (`BufWinLeave`, with no other window still showing it),
* **Then** it is wiped out entirely (`:bwipeout`) — no confirmation, no file written.

* **Given** a preview buffer that has been modified (Vim's own `modified` state — no separate edit-tracking needed),
* **When** it stops being displayed,
* **Then** it is left alone: a normal, persistent buffer from then on.

* **Given** a preview buffer still displayed in another window (e.g. opened via `]J` into a split, one window navigates away but the other still shows it),
* **When** the leaving window's `BufWinLeave` fires,
* **Then** it is not wiped — still visible elsewhere.

* **Given** a buffer that was never flagged as a preview (a normal entry for a file that already existed),
* **When** it stops being displayed while unmodified,
* **Then** nothing happens to it — this only ever applies to preview-flagged buffers.

### **Explicitly out of scope**

Reusing the same buffer ID across consecutive unedited preview stops (renaming it and replacing its content in place, rather than wiping the old one and letting a fresh `:edit` create the next) — no visible difference to the user, and meaningfully more code. Wipe-then-recreate is the chosen approach.

A related but separate issue — `open_date` eagerly creates the destination directory before the buffer exists, so a wiped preview can leave an empty directory behind — is tracked separately in `clean-up-orphaned-empty-directories.md` (backlog), not handled here.

### **Busted Test Cases**

```
it("marks a newly opened buffer as a preview when the file doesn't exist yet", function()
    -- fn.filereadable = 0, fn.bufadd mocked to return a real buffer created via nvim_create_buf
    -- open_date("2026-07-15", "edit")
    -- assert vim.b[buf].jjournal_preview is true
end)

it("does not mark a buffer as a preview when the file already exists", function()
    -- fn.filereadable = 1
    -- assert vim.b[buf].jjournal_preview is nil after open_date
end)

it("wipes an unmodified preview buffer once it's no longer displayed anywhere", function()
    -- capture the BufWinLeave callback; create a real buf, set vim.b[buf].jjournal_preview = true
    -- fn.win_findbuf returns {} (not displayed anywhere)
    -- invoke callback({ buf = buf })
    -- assert vim.api.nvim_buf_is_valid(buf) is false
end)

it("does not wipe a preview buffer that has been modified", function()
    -- same setup, but the buffer's real 'modified' option is set true first
    -- assert the buffer is still valid afterward
end)

it("does not wipe a preview buffer still displayed in another window", function()
    -- fn.win_findbuf mocked to return more than one window
    -- assert the buffer is still valid afterward
end)

it("does not touch a buffer that was never flagged as a preview", function()
    -- a real, unmodified buffer with no jjournal_preview flag
    -- assert the buffer is still valid afterward
end)
```
