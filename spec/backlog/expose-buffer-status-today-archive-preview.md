## **Story: Expose a combined buffer status (today/archive/preview)**

**Use Case:** `journal_status` ("today"/"archive") is already set on every journal buffer via an autocmd, but nothing ever reads it -- it's dead weight, apparently inherited scaffolding that was never wired up to anything. Meanwhile, the new `jjournal_preview` flag (see `recycle-auto-clean-preview-buffers.md`, done) is also invisible to the user, which surfaced as a real usability question: it took some getting used to trust that navigating away from a preview buffer would actually clean it up, precisely because there's no visual signal that a buffer even *is* a preview. Combining both into a single, actually-exposed status lets users (via their own statusline, or any other Neovim setup) see at a glance whether a journal buffer is today's entry, an archived one, or an unsaved preview -- without jjournal dictating what that should look like.

### **Acceptance Criteria**

* **Given** a journal buffer has been opened,
* **When** its status is queried,
* **Then** it resolves to exactly one of `"today"`, `"archive"`, or `"preview"` -- `"preview"` taking priority while the buffer is still an unedited preview, switching to `"today"`/`"archive"` once it's been edited (no longer a preview) or was never a preview to begin with.

* **Given** a buffer outside the configured journal path,
* **When** its status is queried,
* **Then** it resolves to `nil` -- this only ever applies to buffers jjournal itself manages.

* **Given** the status is set,
* **When** inspected directly,
* **Then** it's available as a buffer-local variable (e.g. `vim.b[buf].jjournal_status`), consistent with how `jjournal_preview` already works, so any statusline plugin (lualine, mini.statusline, heirline, native `'statusline'`) can read it without depending on jjournal's Lua API at all.

* **Given** the same status,
* **When** accessed via Lua,
* **Then** `require("jjournal").status(bufnr)` returns the same value as a documented, stable entry point, with `bufnr` defaulting to the current buffer.

### **Open design questions**

* Retire the existing unused `journal_status` var entirely in favor of one unified `jjournal_status` var + `status()` function, rather than keeping both around.
* Add a short lualine snippet to the README as documentation only (no shipped dependency), per the "buffer-local var + thin function, no forced UI" direction already agreed on.
* **Superseded by `pin-buffers-to-exempt-from-auto-cleanup.md`:** `jjournal_preview` no longer exists -- it's been replaced by `jjournal_pinned`, which means something broader ("protected from auto-cleanup," true for an edited buffer or an explicitly-pinned one) rather than "unwritten draft." A buffer showing real, previously-written content that you've merely passed through without editing is now *also* unpinned and cleanup-eligible, which doesn't fit the old `"preview"` label (that implied blank/draft content specifically). Whether this story's third status value should become `"unpinned"`/`"pinned"` instead of `"preview"`, or whether "preview" still has meaning as a narrower case (unpinned *and* the file didn't exist when opened), needs deciding before picking this up -- the acceptance criteria and test cases below still describe the old two-state (preview vs. not) model and should be revisited first.

### **Busted Test Cases**

```
it("resolves to 'today' for today's journal buffer", function() ... end)
it("resolves to 'archive' for a non-today journal buffer", function() ... end)
it("resolves to 'preview' for an unedited preview buffer, taking priority over today/archive", function() ... end)
it("resolves to 'today' or 'archive' once a preview buffer has been edited", function() ... end)
it("resolves to nil for a buffer outside the configured journal path", function() ... end)
it("status(bufnr) returns the same value as the buffer-local variable", function() ... end)
it("status() with no argument defaults to the current buffer", function() ... end)
```
