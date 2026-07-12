## **Story: Stamp journal buffers with entry/date, retire the unused journal_status**

**Use Case:** `journal_status` ("today"/"archive") is set on every journal buffer via an autocmd, but nothing ever reads it -- it's dead weight. Its two values are also misleading: "archive" just means "not today," including a future-dated entry, not "in the past." Meanwhile `jjournal_pinned` (see `pin-buffers-to-exempt-from-auto-cleanup.md`, done) already gives users a real exception signal -- pinned vs. not -- but there's no equally simple way for a statusline plugin to know whether a buffer is one jjournal manages at all, or which date it represents, without reimplementing jjournal's own `base_dir`/`file_path` matching logic itself.

This story replaces `journal_status` with two separate, actually-useful buffer-local stamps: a boolean flag for "jjournal manages this buffer" and a string for "this is the date it represents." Both are set unconditionally on every buffer the existing tagging autocmd already fires for -- no new matching logic needed, since the autocmd's own pattern match (see `fix-autocmd-pattern-for-flat-layouts.md`, done) already guarantees any buffer reaching the callback qualifies. Keeping "is this a journal buffer," "which date," and "is it pinned" as three separate stamps -- rather than folding them into one combined status -- means each answers exactly one question, and none becomes a special case of another.

### **Acceptance Criteria**

* **Given** a journal buffer is opened (matched by the existing `BufReadPost`/`BufNewFile` autocmd),
* **When** it's inspected,
* **Then** `vim.b[buf].jjournal_entry` is `true` and `vim.b[buf].jjournal_date` is the `YYYY-MM-DD` string extracted from its filename.

* **Given** a buffer outside the configured journal path,
* **When** it's inspected,
* **Then** neither `jjournal_entry` nor `jjournal_date` is ever set on it (both read as `nil`) -- this falls out naturally from the autocmd never firing for it, with no extra check needed.

* **Given** the existing `jjournal_pinned` flag,
* **When** this story ships,
* **Then** its behavior and meaning are unchanged -- set independently of `jjournal_entry`/`jjournal_date`, still meaning "protected from auto-cleanup."

* **Given** the now-unused `journal_status` ("today"/"archive") variable,
* **When** this story ships,
* **Then** it's removed entirely -- not renamed, not kept alongside the new stamps.

* **Given** `dates.lua`'s `current_anchor_date`,
* **When** this story ships,
* **Then** it reads `vim.b[0].jjournal_date` (falling back to today only when unset -- i.e. the caller isn't inside a buffer jjournal tagged) instead of independently re-deriving the date by comparing the buffer's directory against the configured journal path and re-parsing its filename.

* **Given** a lualine/statusline setup,
* **When** documented in the README,
* **Then** it shows reading `jjournal_entry`/`jjournal_date`/`jjournal_pinned` directly as buffer-local vars -- no jjournal-side UI shipped, consistent with the "reuse existing/native functionality" direction already agreed.

No Lua accessor function (e.g. `jjournal.is_entry(bufnr)` / `jjournal.date(bufnr)`) is planned -- the three buffer-local vars are the whole interface, consistent with how `jjournal_pinned` already ships today with no accompanying function. Revisit only if a concrete use case for one shows up later.

### **Busted Test Cases**

```
it("tags an opened journal buffer with jjournal_entry = true", function() ... end)
it("tags an opened journal buffer with jjournal_date extracted from its filename", function() ... end)
it("does not touch jjournal_entry/jjournal_date on jjournal_pinned's behavior or vice versa", function() ... end)
it("dates.step/dates.skip anchor off vim.b[0].jjournal_date when set, instead of re-deriving it from the buffer name/path", function() ... end)
it("dates.step/dates.skip fall back to today when jjournal_date is unset", function() ... end)
```

Note: a buffer outside the journal path never getting `jjournal_entry`/`jjournal_date` set doesn't need its own new spec here -- it's already covered structurally by the real, unmocked autocmd-pattern tests added in `fix-autocmd-pattern-for-flat-layouts.md`, which pin down that the tagging autocmd only ever fires for matching files.
