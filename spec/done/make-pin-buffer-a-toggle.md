## **Story: Make pin_buffer a toggle instead of one-way**

**Use Case:** `jjournal.pin_buffer()` (`<leader>jp`) is currently documented and implemented as one-way: once pinned, the only way to make a buffer eligible for auto-cleanup again is to close it (`:bdelete`/`:bwipeout`). That's a deliberate simplicity call, but it means pinning something by mistake -- or changing your mind about keeping an entry open -- has no undo short of losing the buffer entirely. Toggling is a small, low-risk change: flip `vim.b[0].jjournal_pinned` rather than always setting it `true`, and refire the same `User JjournalPinned` autocmd + `:redrawstatus` pair either way so the statusline picks up the change immediately regardless of direction (see `redraw-statusline-on-pin.md`).

One nuance considered and ruled out during design: whether a buffer pinned because it was *edited* (see the `TextChanged`/`TextChangedI` autocmd in `register_autocmds`) should be unpinnable the same way as one pinned only via `<leader>jp`. It should, and there's no meaningful safety gap in doing so -- `BufWinLeave`'s cleanup calls plain `:bwipeout` (no `!`), which Vim itself refuses on a buffer with genuinely unsaved changes (`E89`, verified directly), independently of `jjournal_pinned`. So toggling can never cause a buffer with real unsaved edits to be silently wiped. The only thing `jjournal_pinned` protects on an edited buffer that Vim's own guard doesn't is one that was edited *and saved* (so `modified` is back to `false`) -- toggling that off just makes an already-safely-persisted buffer eligible for cleanup again, same as any other buffer.

**Decision:** toggle flips the single `vim.b.jjournal_pinned` flag unconditionally, regardless of why it was set -- both causes produce the same protected state, so both should be undoable the same way.

### **Acceptance Criteria**

* **Given** an unpinned journal buffer,
* **When** `jjournal.pin_buffer()` runs,
* **Then** the buffer becomes pinned, exactly as today.

* **Given** a journal buffer already pinned (whether via `jjournal.pin_buffer()` or because it was edited),
* **When** `jjournal.pin_buffer()` runs again,
* **Then** the buffer becomes unpinned -- including an edited buffer, which becomes eligible for auto-cleanup again -- and the statusline/`User JjournalPinned` autocmd fire the same way as pinning does.

### **Busted Test Cases**

```
it("unpins an already-pinned buffer when pin_buffer is called again", function() ... end)
it("unpins a buffer that was pinned by editing, not by pin_buffer", function() ... end)
```
