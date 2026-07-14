## **Story: [rfc] Simplify the pin model: drop "ever edited" auto-pin, add a `default_pinned` config instead**

**Use Case:** The current model has two independent ways a buffer becomes pinned: editing it (`TextChanged`/`TextChangedI`, permanent-until-toggled) or explicitly pressing `<leader>jp` (toggle, see `make-pin-buffer-a-toggle.md`). That's two mental models for one piece of state. This story is a genuine open question, not a decided design -- raised as "starting to wonder if we get rid of the 'ever edited' logic" -- about replacing the edit-tracking half entirely with a single `default_pinned` boolean config, leaving pinning under fully explicit/manual control (plus whatever `default_pinned` seeds it to on open).

### **Current model**

* New buffer opens unpinned.
* Editing it (any real change) sets `jjournal_pinned = true`, permanently for that buffer's session lifetime -- not tied to `'modified'`, so saving doesn't undo it.
* `<leader>jp` toggles the flag directly, regardless of which mechanism set it.
* Leaving an unpinned buffer wipes it (`BufWinLeave`, deferred `:bwipeout`, no `!`).

### **Proposed model**

* `config.default_pinned` (boolean, default `false` to preserve today's ephemeral-by-default behavior) -- every buffer jjournal tags (`BufReadPost`/`BufNewFile`) is initialized to this value instead of always starting `false`.
* No `TextChanged`/`TextChangedI` autocmd at all -- editing a buffer no longer has any special effect on its pin state.
* `<leader>jp` / `pin_buffer()` unchanged: still a toggle, still the only way to change a buffer's pin state after it's opened.

### **What actually changes in practice, and why it might be safe**

The scenario that sounds risky -- "won't an edited-but-unpinned buffer now get silently wiped?" -- turns out not to be a *new* risk. Verified directly (`make-pin-buffer-a-toggle.md`'s design notes, and the unwipeable-buffer investigation): `BufWinLeave`'s cleanup uses plain `:bwipeout` (no `!`), which Vim itself already refuses on a buffer with genuinely unsaved changes, completely independently of `jjournal_pinned`. So a buffer with real unsaved edits is protected either way -- removing "ever edited" doesn't reintroduce data loss.

What *does* change: a buffer that was edited **and saved** (so `'modified'` is back to `false`, and Vim's own guard no longer applies) is, today, still kept open for the rest of the session because the edit-tracking flag is permanent. Under the proposed model, with `default_pinned = false`, that same buffer would quietly disappear from the buffer list the moment you leave it, unless you'd explicitly pinned it -- the file is untouched on disk (already saved), just not kept open. This is arguably *more* consistent with "ephemeral unless you say otherwise," but it's a real, user-visible behavior change from what's currently documented in the README's second paragraph ("Editing a buffer keeps it around for good").

### **Open questions**

* Is the behavior change above actually desirable, or is "things I've written in this session just stay open" a property people rely on without realizing it? Needs deliberate confirmation, not just "it's simpler."
* `default_pinned = true` is a different shape of always-on than today's edit-tracking: it pins *every* opened entry unconditionally, including ones only glanced at and never touched -- not "only the ones I actually engaged with." Different use case (build up a full session's worth of open buffers vs. only the ones that mattered); worth being clear these aren't equivalent, not just a config toggle between "smart" and "off".
* Interacts directly with `fire-user-event-on-new-entry.md`: if this lands, a new (possibly template-populated) entry's pin state comes from `default_pinned` alone, with no "did inserting a template count as editing" ambiguity left to resolve. Sequencing this first would simplify that story.
* Migration: this removes a documented, currently-load-bearing behavior described in the README's opening paragraph, not just an internal implementation detail -- would need explicit "what changed and why" documentation (similar to the existing flat-layout "Upgrading" note), not just an updated description.
* Implementation shape: removing the `TextChanged`/`TextChangedI` autocmd removes real code and its tests from `register_autocmds`; `default_pinned` gets read where `jjournal_entry`/`jjournal_date` are currently set (the `BufReadPost`/`BufNewFile` callback), initializing `jjournal_pinned` there instead.

### **Acceptance Criteria**

TBD -- this is a design question to resolve (particularly the first open question above) before it becomes a scheduled story with concrete Given/When/Then criteria.

### **Busted Test Cases**

TBD.
