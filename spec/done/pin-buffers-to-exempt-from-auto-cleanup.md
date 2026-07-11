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

## **Story: Broaden cleanup to any unedited journal buffer, with an explicit pin escape hatch**

**Use Case:** The rule above only ever flags a buffer as a preview when the file doesn't already exist on disk at open time. Browsing history via `[j`/`]j`/`[jj`/`]jj`/`gj`/`<leader>jj` opens a real, permanent-by-default buffer for every *existing* entry you stop at, and none of those ever get cleaned up, however briefly you looked at them -- only entries that happened to be blank when opened do. Over time this leaves a long trail of open buffers behind from nothing more than passing through your history, cluttering `:ls` in exactly the way the original story fixed for blank days but not for written ones.

The fix is to stop distinguishing "did this file exist when opened" and instead ask "did I actually engage with this buffer this visit" -- treating every journal buffer as disposable until it earns being kept, the same way a blank preview already does, just without the new-vs-existing distinction gating it.

"Engaged with" needs to mean more than Vim's own `'modified'` option currently does: `'modified'` reflects whether the buffer *currently* differs from disk, not whether it was edited at any point this visit -- it resets to false on `:w`, and also after a full undo back to the save point. Checking it only at the moment of leaving would wipe a buffer someone genuinely wrote in and saved, discarding that visit's undo history, as long as their last action before navigating away happened to be the save. So editing needs to be tracked as its own persistent, buffer-local state -- set once, the first time it happens, and never cleared for that buffer's lifetime -- rather than read live off `'modified'` at cleanup time.

There's also a case editing can't cover: wanting to keep an *unedited* buffer open on purpose (e.g. a reference entry from weeks back) when you're about to navigate away from it, not just while it's still visible in a split (that case is already covered for free -- see the acceptance criteria below). That needs an explicit escape hatch: a `<leader>jp` ("pin") mapping.

Both signals -- having edited the buffer, and having explicitly pinned it -- mean exactly the same thing to the cleanup logic ("don't wipe this"), so they collapse into one buffer-local flag rather than two: `jjournal_pinned`, replacing `jjournal_preview` outright. Every opened journal buffer starts unpinned, whether or not the file existed on disk yet; it becomes pinned the moment either trigger fires, and stays pinned for the rest of that buffer's lifetime.

Pinning is one-way: there's no unpin mapping. `:bdelete`/`:bwipeout` already closes a buffer regardless of its pinned state, so that's the way back out if something gets pinned that you don't want kept -- no need for jjournal to own a second mechanism for the same thing.

With `is_new_entry` no longer needed to decide whether to flag anything, `open_date` also simplifies: it no longer needs to check `filereadable` or conditionally flag the buffer it opens at all.

### **Acceptance Criteria**

* **Given** a journal buffer that has never been edited or pinned,
* **When** it stops being displayed in any window,
* **Then** it is wiped (`:bwipeout`) -- regardless of whether the file already existed on disk when it was opened.

* **Given** a journal buffer that was edited at any point during this visit,
* **When** it stops being displayed, even if `'modified'` is currently false (edited then saved, or edited then fully undone back to the save point),
* **Then** it is not wiped -- having been edited is a permanent signal for that buffer's lifetime, not a live read of `'modified'` at cleanup time.

* **Given** `<leader>jp` is pressed on a journal buffer that has never been edited,
* **When** it later stops being displayed,
* **Then** it is not wiped.

* **Given** a journal buffer still displayed in another window,
* **When** the leaving window's `BufWinLeave` fires,
* **Then** it is not wiped -- unchanged from today.

* **Given** `use_default_mappings = true`,
* **When** a journal buffer is opened,
* **Then** `<leader>jp` is bound local to that buffer specifically (not globally at `setup()`, unlike every other default mapping), and can be disabled individually like any other entry in `M.mappings` -- pinning only means something for a buffer jjournal actually manages, so pressing `<leader>jp` anywhere else should simply not be mapped at all, rather than silently pinning some unrelated buffer.

### **Open questions -- need deciding when this is picked up**

* Exact public API shape for pinning -- e.g. a parameterless `M.pin_buffer()` operating on the current buffer, dispatched through `M.execute("pin")` as a third early-return case alongside `"search"`.
* Whether pinning should surface any feedback (e.g. `vim.notify`), given there's no visual/statusline indicator of pin state today -- possibly worth tying into the still-backlogged `expose-buffer-status-today-archive-preview.md` instead of adding a one-off notification here.

**Resolved while implementing:** `<leader>jp` is buffer-local (`JjournalMapping.buffer_local = true`), bound per-buffer from the existing `BufReadPost`/`BufNewFile` status-tagging autocmd via a new `bind_buffer_local_mappings(buf)`, rather than globally from `bind_mappings()` at `setup()` time like every other default mapping. This was a direct follow-up question once pinning was implemented (should pressing `<leader>jp` outside a journal buffer do anything?) -- decided no, so it's simply unmapped outside buffers jjournal manages.

### **Consequences for existing tests**

The five Busted Test Cases in this file's original section above get substantially rewritten, not adapted: "marks a newly opened buffer as a preview when the file doesn't exist yet" and "does not mark a buffer as a preview when the file already exists" go away entirely, since every buffer is now eligible for cleanup regardless of whether the file existed at open time. "Does not wipe a preview buffer that has been modified" gets reframed around the new `jjournal_pinned` flag (set via edit-tracking) rather than a live `'modified'` check. "Does not touch a buffer that was never flagged as a preview" no longer applies, since there's no more unflagged case for pre-existing entries -- every journal buffer is now flagged one way or the other.

### **Busted Test Cases**

```
it("wipes an unedited, unpinned journal buffer once it's no longer displayed anywhere, whether or not the file existed before opening", function()
end)

it("does not wipe a buffer that was edited at any point this visit, even though 'modified' is currently false", function()
    -- edit it, then :w (or fully undo back to the save point) so 'modified' is false again
    -- leave it -- still not wiped
end)

it("does not wipe a buffer explicitly pinned via <leader>jp, even though it was never edited", function()
end)

it("does not wipe a buffer still displayed in another window", function()
end)

it("binds <leader>jp alongside the other default mappings, and it can be disabled individually like any other entry in M.mappings", function()
end)
```
