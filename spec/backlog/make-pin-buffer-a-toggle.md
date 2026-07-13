## **Story: Make pin_buffer a toggle instead of one-way**

**Use Case:** `jjournal.pin_buffer()` (`<leader>jp`) is currently documented and implemented as one-way: once pinned, the only way to make a buffer eligible for auto-cleanup again is to close it (`:bdelete`/`:bwipeout`). That's a deliberate simplicity call, but it means pinning something by mistake -- or changing your mind about keeping an entry open -- has no undo short of losing the buffer entirely. Toggling is a small, low-risk change: flip `vim.b[0].jjournal_pinned` rather than always setting it `true`, and refire the same `User JjournalPinned` autocmd + `:redrawstatus` pair either way so the statusline picks up the change immediately regardless of direction (see `redraw-statusline-on-pin.md`).

One nuance to design around: a buffer that's pinned because it was *edited* (see the `TextChanged`/`TextChangedI` autocmd in `register_autocmds`) shouldn't necessarily become unpinnable the same way as one pinned only via `<leader>jp` -- or if it should, that's worth deciding deliberately rather than by accident, since unpinning an edited-but-unsaved buffer could let it be silently wiped later.

### **Acceptance Criteria**

* **Given** an unpinned journal buffer,
* **When** `jjournal.pin_buffer()` runs,
* **Then** the buffer becomes pinned, exactly as today.

* **Given** a journal buffer already pinned via `jjournal.pin_buffer()` (not by having been edited),
* **When** `jjournal.pin_buffer()` runs again,
* **Then** the buffer becomes unpinned, and the statusline/`User JjournalPinned` autocmd fire the same way as pinning does.

### **Busted Test Cases**

```
it("unpins an already-pinned buffer when pin_buffer is called again", function()
    -- arrange / act / assert using the busted framework
end)
```
