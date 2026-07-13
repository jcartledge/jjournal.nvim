## **Story: [tech] Replace the uncaught E89 error with a deliberate outcome when cleanup can't wipe a modified buffer**

**Use Case:** `register_autocmds`' `BufWinLeave` cleanup calls plain `:bwipeout` (no `!`) on an unpinned buffer once it's no longer displayed anywhere. Verified directly against real Neovim, both branches of `'hidden'`:

* **`'hidden'` on (the common case -- AstroNvim's default, most modern configs):** navigating away from a modified, unpinned journal buffer is *not* blocked at all -- `:edit otherfile` (or any navigation) succeeds immediately, and the buffer stays open, hidden, with its unsaved changes fully intact. About one event-loop tick later, the deferred `vim.schedule` cleanup attempts `:bwipeout`, which Vim itself refuses (`E89: No write since last change`) -- but nothing in `register_autocmds` catches that failure, so it propagates out of the scheduled callback and surfaces as an **uncaught error** via Neovim's own scheduler ("Error executing vim.schedule lua callback... E89..."). No data loss, but no acknowledgment either: the buffer just silently survives with an easy-to-miss, badly-timed error as the only trace, appearing well after the user has already moved on to whatever they navigated to.
* **`'hidden'` off:** navigation itself is blocked by Vim's own core `E37: No write since last change` -- entirely independent of jjournal, standard modal Vim (save, `!` to discard, or cancel). jjournal's cleanup never runs for this case at all, since the switch away never completes. Not in scope for this story -- there's nothing jjournal-specific to fix here.

So the gap is specifically the `'hidden' = true` case: the *outcome* (buffer survives, no data loss) is already correct. What's missing is deliberate handling of that outcome instead of an uncaught, confusingly-timed Vim error.

### **Design options**

1. **Catch the failure, `vim.notify` a clear message.** Wrap the `:bwipeout` call in `pcall`; on failure, `vim.notify("jjournal: kept <date>'s buffer open -- it has unsaved changes", vim.log.levels.WARN)` (or similar) instead of letting `E89` leak out uncaught. Smallest change, same outcome as today, just communicated deliberately instead of accidentally. Doesn't change whether the buffer is discoverable later beyond whatever `vim.notify` history the user's setup keeps.
2. **Same as (1), plus auto-pin the buffer at that moment** (`vim.b[buf].jjournal_pinned = true`, firing the same `User JjournalPinned` + `:redrawstatus` pair `pin_buffer()` does). Makes the buffer's now-protected status honest and *visible* (shows up in the statusline/tabline pin indicator) rather than an invisible, unmarked exception that happens to survive only because this one cleanup attempt failed -- without this, the buffer is one `BufWinLeave` retry away from vanishing the instant it becomes saveable-and-then-saved-and-then-modified-again in a way that finally lets `:bwipeout` succeed unnoticed. Slightly more invasive: this is jjournal actively changing buffer state in response to a failure, not just reporting it.
3. **Prompt to save/discard/keep right there** (`vim.ui.select` or similar). Considered and leaning against: by the time this fires, the user has already navigated away and moved on to something else (the whole point of the `vim.schedule` deferral) -- surfacing a decision prompt at that point would interrupt whatever they're doing next, out of context. Feels like a poor fit for a plugin whose stated ethos (README) is staying unobtrusive and never losing data, not for actively demanding decisions.

### **Open questions**

* Does this scenario come up often enough in practice to be worth solving, or is it rare enough (requires: real edit, then navigate away, with the buffer never subsequently saved) that a quieter fix suffices?
* If auto-pinning (option 2): should this get logged/remembered anywhere beyond the buffer's own lifetime, given jjournal's `jjournal_pinned` is buffer-local and doesn't survive the buffer being closed or Neovim restarting -- or is "stays open for the rest of this session" a sufficient guarantee?
* What should the notification message actually say -- does naming the specific date/file help, or is a generic message enough? (`vim.b[buf].jjournal_date` is available in the callback if useful.)
* Is `vim.log.levels.WARN` the right severity, or should this be `INFO` given nothing is actually going wrong from the user's perspective (their data is safe either way)?

### **Acceptance Criteria**

TBD -- pending a decision among the options above (or a different approach) before this moves to `spec/doing/`.

### **Busted Test Cases**

TBD -- will need a real, unmocked spec pinning down whatever the deferred `vim.schedule` callback actually does on failure (a mocked `nvim_create_autocmd` invocation wouldn't exercise whether `:bwipeout` genuinely fails/succeeds against a real modified buffer), in the style of the "does not wipe a buffer that was edited..." specs already in the "buffer cleanup and pinning autocmds" describe block.
