## **Story: Make navigation mappings buffer-local where they only make sense in-buffer**

**Use Case:** `pin-buffers-to-exempt-from-auto-cleanup.md` made `<leader>jp` buffer-local (bound only inside buffers jjournal manages) rather than global, on the reasoning that pinning has no meaning outside a journal buffer -- pressing it elsewhere should simply do nothing, not silently pin some unrelated buffer.

The same question applies to the rest of `M.mappings`, and probably has different answers for different entries:

* `gj` (today) and `<leader>jj` (prompt) are genuine entry points -- pressing them from any buffer, to jump *into* the journal, is the whole point. These should almost certainly stay global.
* `[jj`/`]jj` (step) and `[j`/`]j` (skip) are inherently *relative* operations -- they shift or search from wherever the current buffer is anchored (`current_anchor_date`, which falls back to today when the buffer is outside the journal path). Pressing them from an arbitrary unrelated buffer today "works" (falls back to stepping/skipping from today), but it's not obviously a meaningful thing to want to do from outside the journal -- unlike `gj`, there's no clear reason to invoke a *relative* motion with no journal context to be relative *to*. Worth reconsidering as buffer-local, following the `<leader>jp` precedent.
* `<leader>fj` (search) searches the whole backlog regardless of where you currently are, more like `gj` than like step/skip -- probably stays global, but worth deciding explicitly rather than leaving it implicit.

This isn't a foregone conclusion, though: there's a real counterargument for step/skip staying global, e.g. "step relative to today" as a deliberate, useful fallback when pressed with no journal context (a more roundabout way of writing `gj` then stepping, but in one keypress). This needs actually deciding, not just defaulting to "more buffer-local is more consistent."

### **Open questions -- need deciding when this is picked up**

* Should `[jj`/`]jj`/`[j`/`]j` become buffer-local (via `JjournalMapping.buffer_local`, same mechanism as `<leader>jp`), or is the "falls back to today" behavior when invoked from outside the journal actually a feature worth keeping global?
* Does `<leader>fj` stay global? (Leaning yes, but decide explicitly.)
* If step/skip become buffer-local, does that change anything about `current_anchor_date`'s outside-journal-path fallback behavior (`scope-current-date-detection-to-journal-path.md`, done) -- or does that fallback simply become dead code once it's unreachable via the default mappings (still reachable via `execute()`/`resolve_date()` directly, for anyone with `use_default_mappings = false`)?

### **Acceptance Criteria**

Not yet written -- deferred until the open questions above are resolved.
