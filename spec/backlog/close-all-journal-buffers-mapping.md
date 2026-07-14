## **Story: [idea] `<leader>jC` to close all journal buffers at once**

**Use Case:** Raised as a new idea, not yet scoped. Currently the only way to close a journal buffer is one at a time (`:bdelete`/`:bwipeout`, or letting an unedited one auto-close on its own via `BufWinLeave`) -- there's no bulk "I'm done, close everything jjournal has open" action, which could matter after a session where several entries have accumulated (edited-and-pinned ones especially, since those never close themselves).

### **Open questions**

* **Scope of "all":** every buffer with `vim.b.jjournal_entry == true`, or only pinned ones (unpinned/untouched ones already self-close on their own via the existing cleanup, so arguably nothing to bulk-close there unless they're currently displayed)?
* **Pinned/edited buffers with unsaved changes:** skip them (respecting Vim's normal "won't discard unsaved work" behavior, the same guard `BufWinLeave`'s cleanup already relies on), force-discard with `bwipeout!` (destructive, needs to be very deliberate given jjournal's whole ethos is "never lose data"), or something in between (e.g. close everything *safe* to close and report/notify what got skipped and why)?
* **Windows, not just buffers:** does this only remove them from the buffer list, leaving whatever window they were in showing something else (Vim picks the next buffer automatically), or does it also close split windows that only existed to show a journal buffer?
* **Mapping shape:** global (not buffer_local) like `gj`/`<leader>jj`/`<leader>fj`/`<leader>fj`, since "close everything" isn't relative to where you currently are -- consistent with the existing pattern of buffer_local only for things that need a buffer jjournal already manages as context (step/skip/pin).
* Naming: `<leader>jC` (capital, to read as a distinct "bulk"/heavier action from the existing lowercase `<leader>jj`/`<leader>jp`) is the proposed key, not yet confirmed against the rest of the mapping table for collisions or convention fit.

### **Acceptance Criteria**

TBD -- not yet scoped; the unsaved-changes handling question in particular needs a decision before this has concrete Given/When/Then criteria.

### **Busted Test Cases**

TBD.
