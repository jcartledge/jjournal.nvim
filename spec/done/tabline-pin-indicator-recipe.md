## **Story: [docs] Add a tabline/winbar recipe for the pinned indicator, AstroNvim-compatible**

**Use Case:** The README's "Buffer status" section only shows a statusline recipe for surfacing `vim.b.jjournal_pinned`. A statusline is shared across the whole window and often doesn't show per-buffer detail once several journal entries are open in different tabs/splits -- a tabline or winbar entry makes it possible to tell, at a glance across multiple open buffers, which ones are pinned. This is purely a documentation addition (no plugin code changes): a second recipe alongside the existing one, using the same `vim.b.jjournal_entry`/`jjournal_pinned` variables and the `User JjournalPinned` autocmd (see `redraw-statusline-on-pin.md`), styled for AstroNvim/Heirline's tabline (`opts.tabline`) the same way the existing recipe targets `opts.statusline`.

### **Acceptance Criteria**

* **Given** a reader following the README's "Buffer status" section,
* **When** they want a pin indicator in their tabline/winbar rather than (or in addition to) their statusline,
* **Then** the README shows a working, AstroNvim/Heirline-compatible recipe for it, wired to `User JjournalPinned` the same way the statusline recipe is.

### **Busted Test Cases**

N/A -- documentation-only change; no plugin behavior to pin down with a spec.

## **Design notes from verifying against the real AstroNvim/Heirline code**

Two things were confirmed empirically (loading the real `astrocore`/`astroui`/`heirline.nvim` code headless, through `heirline.setup()` + `eval_tabline()`, not just an isolated helper) before writing the recipe:

* **Don't add a second `make_buflist(...)` to `opts.tabline`.** AstroNvim's default tabline is *already* `status.heirline.make_buflist(status.component.tabline_file_info())` (see `astronvim/plugins/heirline.lua`). Naively following the statusline recipe's `table.insert(opts.statusline, ...)` pattern and inserting a second buflist into `opts.tabline` would render a whole duplicate row of buffer tabs alongside the existing one, not add a pin marker to it. The correct extension point is `status.component.tabline_file_info(opts)`, which threads `opts` through `status_utils.setup_providers` -- that function only touches numeric indices 1-8 (one per named provider: file_icon, bufnr, unique_path, filename, filetype, file_modified, file_read_only, close_button) and returns `opts` otherwise untouched, so an extra `opts[9] = { condition = ..., provider = ... }` survives through to `component.builder` as an additional child appended after the stock ones. The recipe replaces AstroNvim's existing tabline entry with this extended version, rather than inserting anything new.
* **Per-buffer components must read `vim.b[self.bufnr]`, not `vim.b[0]`.** A `make_buflist` child component renders once per entry in `vim.t.bufs`, most of which aren't the current buffer -- `self.bufnr` (set by `make_buflist`'s own wrapping) is what identifies which buffer a given render pass is for. Verified directly: pinning one buffer while a different one is current correctly marks only the pinned one in the rendered tabline string, with the other buffer's entry unaffected.

### **Revision: corrected the statusline recipe's explanation, and dropped its now-unneeded `init`**

While verifying the above, the earlier `redraw-statusline-on-pin.md` explanation turned out to be inaccurate in a way worth fixing here since both recipes sit next to each other in the README. See that story's own trailing revision for the detail; the summary: the statusline component doesn't need `init = require("astroui.status").init.update_events({...})` at all. Heirline only engages its per-window `_win_cache` for a component when its native `update` field is set (`heirline/statusline.lua`'s `_eval`); since the recipe replaced `update` with `init`, no caching was ever active for it in the first place, so it was already recomputing fresh on every redraw regardless of which event fired `:redrawstatus` -- confirmed by flipping `vim.b.jjournal_pinned` directly (bypassing `pin_buffer()` and its `User JjournalPinned` autocmd entirely) and seeing the change reflected immediately. `init`/`update_events` was therefore dead weight for this specific recipe; removed for a simpler, equally-verified-correct example. The tabline recipe here follows the same now-verified-simplest pattern: no `update`, no `init`.
