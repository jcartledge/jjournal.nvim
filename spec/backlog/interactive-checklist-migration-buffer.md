## **Story: Interactive checklist-buffer workflow for migration**

**Use Case:** Running migration as a plain function call is fine, but reviewing and executing a batch of file moves entirely inline, as an editable checklist you can look over before committing, would be a nicer and safer review experience than a dry-run printout. The idea: calling the entry point opens a named, unsaved buffer (e.g. backed by a path under `/tmp`) listing the planned moves as markdown-style checkboxes:

```
* [ ] /Users/jcartledge/notes/journal/2026-07-07.md -> /Users/jcartledge/notes/journal/2026/07/2026-07-07.md
```

The user can edit the buffer (expected to be rare). Saving it (`:w`) prompts them to confirm before actually running the migration, and results are written back into the buffer live as it executes (e.g. checking off completed lines).

This builds on the simpler `migrate-between-path-template-layouts` story's discover/plan/execute primitives (`require("jjournal.migrate").run`) — it's an alternate, interactive front end around the same backend, not a replacement for it.

May or may not get built — captured here so the idea and its open questions aren't lost, not because it's committed to.

### **What's already decided**

* The entry point opens a real, named buffer (not a pure in-memory scratch buffer) so it can be saved.
* Each line is one planned move, formatted as `* [ ] <old path> -> <new path>`.
* Saving the buffer triggers a confirmation prompt before migration actually runs — saving alone doesn't execute it.
* Results are reflected back into the buffer as migration runs (not just a final summary elsewhere).

### **Open design questions — not yet decided, need discussion before implementation**

* **What does editing the buffer actually control?** Is it purely a checkbox on/off toggle for including/excluding a line (skip that move), or can the user rewrite the `-> <new path>` side to retarget an individual file's destination? If retargeting is allowed, does the retargeted destination get re-validated against anything, or is the buffer trusted as-is once edited?
* **What do `[ ]` and `[x]` mean before migration runs?** Are they purely output markers migration fills in as it completes lines, or can the user pre-check/uncheck them to mean something (e.g. pre-checked = skip)?
* **Is deleting a line equivalent to skipping that file?** Or does the plan need every discovered file to have a corresponding line, with some other mechanism to exclude one?
* **How does saving actually trigger migration?** Presumably a buffer-local `BufWritePre`/`BufWriteCmd`/`BufWritePost` autocmd on that one buffer — which of these, and does the confirmation prompt block/cancel the actual filesystem write to the plan file itself, or let it save normally and separately trigger the run?
* **What happens on "no" at the confirmation prompt?** Does the plan file just save as-is with no migration run, or does something else happen?
* **How is live progress actually shown?** Filesystem renames are near-instant, so without deliberately spacing updates across the event loop (e.g. `vim.schedule`/`vim.defer_fn`/forced `redraw`), the buffer likely jumps straight to its final state rather than visibly updating line-by-line. Is genuine incremental visual feedback worth the added complexity here, or is a fast "all done" update acceptable?
* **What does a failed line look like afterward?** Some inline marker and message (e.g. `* [!] ... -- rename failed: <reason>`) needs a concrete format.
* **Is re-saving the same buffer after a run idempotent/resumable?** i.e. does saving again only retry failed/unchecked lines, or does it reprocess everything (which should mostly no-op for already-moved files, but hasn't been thought through)?
* **Testing approach.** This goes meaningfully beyond what `setup_test`'s existing mocking supports — real buffer content, a buffer-scoped autocmd firing on save, and incrementally rewriting lines mid-execution all need a testing pattern that doesn't exist yet in this codebase. Worth resolving before committing to this UI, given how much this project values test coverage.

### **Busted Test Cases**

Not written — acceptance criteria aren't settled enough yet. Resolve the open questions above first.
