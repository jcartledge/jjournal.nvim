## **Story: Cache or bound the directory scan behind skip navigation**

**Use Case:** `dates.skip` (and, transitively, `resolve_date`/`execute` for the `skip_prev`/`skip_next` targets) resolves its destination by calling `all_available_dates`, which combines `dates_from_disk` (a recursive `vim.fn.glob(base_dir .. "**/*", ...)` over the *entire* configured journal directory) with `dates_from_buffers` (a scan of every loaded buffer), rebuilds the full sorted array, then indexes into it. This runs from scratch on every single skip keypress, with no caching between calls and no short-circuiting once the requested count of matches is found.

The cost of a skip therefore scales with the total number of entries the journal has ever accumulated, not with how far the skip is actually travelling (jumping to the very next entry costs the same full-directory scan as jumping to the 50th). For a journal with years of daily entries, this is a full recursive directory walk plus parse on every navigation, run fresh each time. `vim.fn.glob` is native and fast in practice for a few thousand files, so this likely isn't user-visible today, but it's an unbounded-growth pattern worth revisiting before it is.

Spotted while implementing `support-count-prefix-step-navigation.md` (a count-prefixed skip walks further into the same full scan, making the cost more visible), but is pre-existing to skip navigation generally, not introduced by that story.

### **Open questions — need deciding when this is picked up**

* Cache the sorted date array (and invalidate on filesystem change / buffer list change), vs. avoid materializing the full array at all (e.g. incrementally glob outward from the current date's containing directory/directories, relying on file_path's date-partitioned structure where one exists)?
* Is a cache invalidation story (watching for external file changes, new buffers, deletions) worth the complexity here, or is a plain per-call scan actually fine given `vim.fn.glob`'s native performance, and this should be closed as "measured, not a real problem" instead?
* Should this be measured first (e.g. a manual benchmark against a few thousand synthetic entries) before deciding whether any change is warranted at all?

### **Acceptance Criteria**

Not yet written — deferred until the open questions above are resolved and a specific approach is chosen.

### **Resolution: measured, not a real problem — closed 2026-07-12**

Answered the third open question above directly: benchmarked `vim.fn.glob(base_dir .. "**/*", ...)` plus the parse-and-sort step that follows it, against real synthetic journal directories, using the default nested `%Y/%m/%Y-%m-%d.md` layout (a flat layout was also measured and performs almost identically — total file count dominates, not directory structure):

* 100 entries: ~1.5ms total
* 1,000 entries (~3 years of daily journaling): ~16ms
* 5,000 entries (~14 years): ~80ms
* 20,000 entries (~55 years): ~325ms (roughly two-thirds `glob()`, one-third parse/sort)

At any realistically-sized journal — even 15-20 years of daily entries — a single skip keypress costs well under 100ms, imperceptible in practice. It only becomes a barely-noticeable pause at the 20,000-entry mark, representing over half a century of unarchived daily entries in one journal. This confirms the use case's own speculation: `vim.fn.glob` is fast enough in practice that this pattern isn't a real problem at any scale a single daily journal is likely to reach.

Decision: close without implementing either option from the first open question (caching, or bounding the scan to date-partitioned subdirectories). Both carry real ongoing complexity cost — cache invalidation is the classically hard part of caching, and directory-bounded scanning only helps when `file_path` happens to nest by date, so it'd be an asymmetric optimization for a cost that isn't currently real. Revisit if an actual usage pattern (e.g. multiple entries per day sustained over decades, or a shared/team journal) ever makes this measurably bite — the benchmark methodology above (synthetic directories generated via a script, timed with real `glob()` calls) is reusable if that happens.
