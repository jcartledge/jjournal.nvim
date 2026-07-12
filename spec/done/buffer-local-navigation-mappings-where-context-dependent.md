## **Story: Make navigation mappings buffer-local where they only make sense in-buffer**

**Use Case:** `pin-buffers-to-exempt-from-auto-cleanup.md` made `<leader>jp` buffer-local (bound only inside buffers jjournal manages) rather than global, on the reasoning that pinning has no meaning outside a journal buffer -- pressing it elsewhere should simply do nothing, not silently pin some unrelated buffer.

The same question applies to the rest of `M.mappings`, and probably has different answers for different entries:

* `gj` (today) and `<leader>jj` (prompt) are genuine entry points -- pressing them from any buffer, to jump *into* the journal, is the whole point. These should almost certainly stay global.
* `[jj`/`]jj` (step) and `[j`/`]j` (skip) are inherently *relative* operations -- they shift or search from wherever the current buffer is anchored (`current_anchor_date`, which falls back to today when the buffer is outside the journal path). Pressing them from an arbitrary unrelated buffer today "works" (falls back to stepping/skipping from today), but it's not obviously a meaningful thing to want to do from outside the journal -- unlike `gj`, there's no clear reason to invoke a *relative* motion with no journal context to be relative *to*. Worth reconsidering as buffer-local, following the `<leader>jp` precedent.
* `<leader>fj` (search) searches the whole backlog regardless of where you currently are, more like `gj` than like step/skip -- probably stays global, but worth deciding explicitly rather than leaving it implicit.

This isn't a foregone conclusion, though: there's a real counterargument for step/skip staying global, e.g. "step relative to today" as a deliberate, useful fallback when pressed with no journal context (a more roundabout way of writing `gj` then stepping, but in one keypress). This needs actually deciding, not just defaulting to "more buffer-local is more consistent."

### **Decided**

* `[jj`/`]jj`/`[j`/`]j` become buffer-local, via the same `JjournalMapping.buffer_local` mechanism already used for `<leader>jp`.
* `<leader>fj` (search) stays global, alongside `gj` and `<leader>jj` -- a backlog-wide lookup, not tied to current position.
* `current_anchor_date`'s outside-journal-path fallback to today (`scope-current-date-detection-to-journal-path.md`, done) keeps its current logic unchanged -- it's still a real correctness guard for direct `execute()`/`resolve_date()` callers (e.g. custom global mappings with `use_default_mappings = false`), not dead code. What changes is framing only: its docstring and the specs exercising that fallback get reworded to describe direct-API behavior rather than implying it's reachable by pressing a default mapping from outside the journal, since that's no longer true.

### **Acceptance Criteria**

* **Given** `use_default_mappings = true`,
* **When** `setup()` runs,
* **Then** `[jj`/`]jj`/`[j`/`]j` are *not* bound globally -- only `gj`, `<leader>jj`, and `<leader>fj` are.

* **Given** `use_default_mappings = true`,
* **When** a journal buffer is opened,
* **Then** `[jj`/`]jj`/`[j`/`]j` (and `<leader>jp`, unchanged from the prior story) are bound local to that buffer, wired to `execute()` with the right target/cmd/count and desc.

* **Given** any buffer_local mapping is individually disabled via `M.mappings[lhs] = false`,
* **When** a journal buffer is opened,
* **Then** it is not bound there either -- unchanged mechanism, now exercised by more than one entry.

* **Given** `dates.step`/`dates.skip` (via `resolve_date`/`execute`) are called directly from outside the journal path,
* **When** they resolve the current anchor,
* **Then** behavior is unchanged from before this story (falls back to today) -- this story only changes which mappings can reach that path by default, not the underlying function.

### **Busted Test Cases**

```
it("does not bind step/skip mappings globally", function()
    -- generalizes the existing pin-only "does not bind a buffer_local
    -- mapping globally" spec into a loop over every buffer_local entry
end)

it("binds step/skip mappings local to the buffer when a journal buffer is opened", function()
    -- generalizes the existing pin-only "binds buffer-local mappings..."
    -- spec into a loop over every buffer_local entry
end)
```

No new specs needed for `current_anchor_date` itself or the disabled-mapping/use_default_mappings=false paths -- those are already covered generically and don't vary per mapping. Existing specs that exercise the outside-path fallback get their descriptions/comments reworded only, not their assertions.
