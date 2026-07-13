## **Story: [fix] Redraw the statusline when a buffer is explicitly pinned**

**Use Case:** `<leader>jp` (`jjournal.pin_buffer`) sets `vim.b[0].jjournal_pinned = true` so a statusline plugin reading that variable (see README's "Buffer status" section) can show a pinned indicator. But setting a buffer-local variable doesn't itself prompt Neovim to repaint the statusline -- most statusline plugins only redraw on specific events (`CursorMoved`, `ModeChanged`, `BufEnter`, a timer, etc.), none of which `<leader>jp` triggers on its own. The result: after pinning, the statusline keeps showing the old (unpinned) state until some unrelated action happens to trigger a redraw, making it look like pinning silently didn't work. The auto-pin-on-edit path (the `TextChanged`/`TextChangedI` autocmd) doesn't show this problem in practice, since typing itself generates events most statuslines already redraw on -- this only affects the explicit pin action.

### **Acceptance Criteria**

* **Given** a journal buffer that isn't yet pinned,
* **When** `jjournal.pin_buffer()` runs (e.g. via `<leader>jp`),
* **Then** `vim.b[0].jjournal_pinned` is set to `true` and the statusline is redrawn immediately, without waiting for an unrelated event.

### **Busted Test Cases**

```
it("redraws the statusline after pinning the current buffer", function()
    -- arrange / act / assert using the busted framework
end)
```
