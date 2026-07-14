## **Story: [idea] `gj`/visual `gj` jumps to a date parsed under the cursor/selection instead of today**

**Use Case:** Raised as a "might be useful or feature creep" idea, not yet scoped. `gj` currently always goes to today, from anywhere. The idea: if a `YYYY-MM-DD`-shaped string is under the cursor (normal mode) or selected (visual mode), `gj` jumps to *that* date's entry instead -- similar in spirit to how `gf`/`gx` act on whatever's under the cursor. Most directly useful while reading an entry that mentions another date in its prose (e.g. "see notes from 2026-06-01") and wanting to jump straight there, without retyping the date into the `<leader>jj` prompt.

### **Open questions**

* `gj` already overrides a stock Vim mapping (`gj` = move down a screen line rather than a file line) globally, everywhere, not just in journal buffers -- that's an existing, deliberate design choice. Adding cursor-position-dependent branching on top (sometimes today, sometimes some other date, depending on what's under the cursor) stacks a second kind of special-casing onto an already-repurposed key, with no visual indication of which behavior will trigger. Worth weighing whether that's still discoverable/predictable enough, or whether a separate mapping is clearer.
* Scope of "parseable date": strictly `YYYY-MM-DD` (matches jjournal's own internal date handling exactly, no new parsing dependency) vs. looser natural-language dates ("next monday", relative dates) -- the latter is a materially bigger, fuzzier feature with its own edge cases and probably belongs in a separate story if pursued at all.
* Does this only make sense inside a buffer jjournal already manages (like the buffer-local step/skip mappings), or should it work globally the way `gj` currently does? If buffer-local-only, `gj` would need to mean different things depending on where it's pressed from, on top of the cursor-position branching above.
* Whether this is worth it at all now that `<leader>jj`'s prompt exists and step/skip take count prefixes -- the main remaining case this adds is "date mentioned in prose, not the file you're currently navigating from."

### **Acceptance Criteria**

TBD -- not yet scoped; open questions above need resolving first, including whether this is worth building at all.

### **Busted Test Cases**

TBD.
