## **Story: [docs] Add a tabline/winbar recipe for the pinned indicator, AstroNvim-compatible**

**Use Case:** The README's "Buffer status" section only shows a statusline recipe for surfacing `vim.b.jjournal_pinned`. A statusline is shared across the whole window and often doesn't show per-buffer detail once several journal entries are open in different tabs/splits -- a tabline or winbar entry makes it possible to tell, at a glance across multiple open buffers, which ones are pinned. This is purely a documentation addition (no plugin code changes): a second recipe alongside the existing one, using the same `vim.b.jjournal_entry`/`jjournal_pinned` variables and the `User JjournalPinned` autocmd (see `redraw-statusline-on-pin.md`), styled for AstroNvim/Heirline's tabline (`opts.tabline`) the same way the existing recipe targets `opts.statusline`.

### **Acceptance Criteria**

* **Given** a reader following the README's "Buffer status" section,
* **When** they want a pin indicator in their tabline/winbar rather than (or in addition to) their statusline,
* **Then** the README shows a working, AstroNvim/Heirline-compatible recipe for it, wired to `User JjournalPinned` the same way the statusline recipe is.

### **Busted Test Cases**

N/A -- documentation-only change; no plugin behavior to pin down with a spec.
