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

## **Revision: `:redrawstatus` alone doesn't reach caching statusline frameworks**

**Use Case:** `:redrawstatus` (the fix above) forces Neovim to re-evaluate the `'statusline'` option, but doesn't help if the plugin behind that option caches its own rendered output and only recomputes on specific autocmd events -- which is exactly how AstroNvim's Heirline-based statusline works (and the pattern the README's own recipe follows). AstroUI's `status.component.builder` accepts an `update` list of events that, when fired, clear a per-window render cache (`astroui.status.init.update_events`); until one of those events fires, Heirline just returns the stale cached string, so `:redrawstatus` has nothing new to show. `<leader>jp` doesn't match any of the events in the README recipe's `update = { "BufEnter", "TextChanged", "TextChangedI" }` list, so the pin indicator never appears -- reproduced directly by loading the real `astroui`/`heirline.nvim` code headless and confirming the component's `_win_cache` stays populated across a `pin_buffer()` + `redrawstatus` call, and only clears once a `User` autocmd matching an entry in `update` is fired.

Since there's no stock Neovim event for "a jjournal buffer was just pinned," jjournal needs to emit its own: firing a `User` autocmd gives any event-driven statusline (Heirline via `update`, or a custom lualine autocmd-triggered refresh) something concrete to listen for, the same way AstroUI's own docs show hooking a third-party `User` event (e.g. `{ "User", pattern = "LspProgressUpdate" }`). The existing `:redrawstatus` call stays -- it's still what makes a non-caching statusline (a plain `'statusline'` string, or one that recomputes unconditionally) reflect the change immediately.

### **Acceptance Criteria**

* **Given** a journal buffer that isn't yet pinned,
* **When** `jjournal.pin_buffer()` runs,
* **Then** it fires a `User JjournalPinned` autocmd (in addition to setting `vim.b[0].jjournal_pinned` and calling `:redrawstatus`), so statusline components that only refresh on specific autocmd events (e.g. AstroNvim/Heirline's `update` list) can register `{ "User", pattern = "JjournalPinned" }` and pick up the change immediately.

### **Busted Test Cases**

```
it("fires a User JjournalPinned autocmd when pinning the current buffer", function()
    -- arrange / act / assert using the busted framework
end)
```
