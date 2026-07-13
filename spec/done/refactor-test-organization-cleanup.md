## **Story: [tech] Refactor pass: misplaced test and a stale comment**

**Use Case:** A deliberate refactoring review of `lua/jjournal/*.lua` and `tests/jjournal_spec.lua` (prompted by adding red/green/refactor to the definition of done) found two small things worth cleaning up. Neither changes behavior.

1. `tests/jjournal_spec.lua`'s `"jjournal config"` describe block contains a test ("normalizes a configured path that has no trailing slash") that doesn't belong there -- it tests path normalization, the same concern as every test already in `"jjournal.resolve_path"`, just indirectly (through `open_date` and a mocked `vim.cmd`) instead of calling `resolve_path` directly. CLAUDE.md's testing conventions call for one describe block per public function and no overlapping groupings; this one is both misplaced and needlessly indirect for what it's actually checking.
2. The `"jjournal.pin_buffer"` describe block's comment above the `User JjournalPinned` test says the event exists so "caching statusline frameworks can invalidate in time" and cites "AstroNvim/Heirline's `update` list" as the example -- language carried over from `redraw-statusline-on-pin.md`'s second revision. Its own *third* revision (written after actually tracing Heirline's `_eval`) found that framing was wrong: the shipped Heirline recipe never used `update`/caching in the first place, and a follow-up attempt to compose `update` with a custom-event `init` didn't reliably invalidate anyway. The comment still describes the superseded mechanism.

Considered and rejected in the same pass: merging `bind_mappings`/`bind_buffer_local_mappings` in `init.lua` (roughly 6 duplicated lines of `vim.keymap.set` boilerplate). The merged version needs a `(spec.buffer_local == true) == buffer_local` style comparison in place of two plain boolean checks, which reads worse than the duplication it removes, and the two functions' docstrings each explain a genuinely different *why* (one-time global binding at `setup()` vs. per-buffer binding tied to a buffer jjournal actually manages) that's worth keeping visually separate. Not changed.

### **Acceptance Criteria**

* **Given** the test suite,
* **When** reviewed against CLAUDE.md's "one describe block per public function" convention,
* **Then** the no-trailing-slash normalization test lives under `"jjournal.resolve_path"` and calls `resolve_path` directly, and the `"jjournal config"` describe block only contains genuine config-default tests.

* **Given** the `"jjournal.pin_buffer"` describe block's comment about `User JjournalPinned`,
* **When** compared against the corrected mechanism in `redraw-statusline-on-pin.md`'s third revision,
* **Then** the comment accurately describes the event as a general extension point for frameworks that do cache (e.g. lualine), not as something the shipped Heirline recipe itself needs.

### **Busted Test Cases**

No new behavior -- existing specs are relocated/renamed, not added. `./tests/scripts/run.sh` must still pass at 90/90 with 100% coverage throughout (this is a pure refactor: red/green stays green, no new red step).
