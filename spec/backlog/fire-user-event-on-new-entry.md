## **Story: [feature] Fire a `User JjournalNewEntry` autocmd when a brand-new entry is created**

**Use Case:** `User JjournalPinned` (see `redraw-statusline-on-pin.md`) exists precisely so third-party code can react to a jjournal state change without reimplementing jjournal's own pattern-matching. There's no equivalent for "a brand-new entry was just created" -- someone wanting to auto-insert a template (frontmatter, a heading, a prompt) into a fresh entry currently has to build their own `BufNewFile` autocmd against `base_dir`/`file_path`, duplicating logic jjournal already owns (see the "composability" draft's "real gap, not a composability story" section). Mirroring the existing precedent: fire `User JjournalNewEntry` from the `BufNewFile` branch of the tagging autocmd in `register_autocmds` (not `BufReadPost` -- opening an already-existing entry isn't a "new" one).

**Open question this needs resolving before implementation, not after:** how does this interact with the edit-tracking ("ever edited") auto-pin logic? If a listener uses this event to insert template content (e.g. `nvim_buf_set_lines`), does that insertion itself get treated as "an edit" the same way real typing does, permanently pinning -- and therefore keeping open -- *every single new entry*, even ones the user never actually engages with beyond the auto-inserted template? That would quietly defeat the ephemeral-by-default design for the entire class of templated entries. This question is also directly entangled with `simplify-pin-model-remove-ever-edited-auto-pin.md`: if that redesign lands first, "ever edited" no longer exists to interact with, and this event's semantics get simpler (a new entry's pin state would just come from `default_pinned`, same as any other). Worth sequencing these two stories deliberately rather than landing this one first and having to revisit it.

### **Acceptance Criteria**

TBD -- blocked on resolving the interaction above (either by deciding this fires late enough / in a way that doesn't itself count as "editing", or by the ever-edited redesign landing first and removing the question).

### **Busted Test Cases**

TBD.
