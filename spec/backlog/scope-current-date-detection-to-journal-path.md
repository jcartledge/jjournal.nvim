## **Story: [tech] Scope current-date detection to the configured journal path**

**Use Case:** `get_current_date_coordinate()` matches the *current buffer's filename* against a `YYYY-MM-DD` pattern regardless of which directory it's in. Opening an unrelated file elsewhere that happens to be named like a journal entry (e.g. a changelog dated `2026-07-09.md` outside `~/notes/journals/`) would be treated as the "current" journal date for navigation purposes, silently producing wrong results.

### **Acceptance Criteria**

* **Given** the current buffer's file is outside the configured journal path, even if its name matches the date pattern,
* **When** navigation resolves the "current" date,
* **Then** it falls back to today's date rather than treating the unrelated file as current.
* **Given** the current buffer's file is inside the configured journal path and matches the date pattern,
* **When** navigation resolves the "current" date,
* **Then** it uses that file's date, as it does today.

### **Busted Test Cases**

```
it("falls back to today when the current buffer is date-named but outside the journal path", function()
    -- stub vim.fn.expand/fnamemodify to return a date-named file outside the configured path,
    -- resolve 'prev' or 'next' and assert the navigation treats today as current, not that file's date
end)

it("still uses the buffer's date when it is inside the configured journal path", function()
    -- existing behavior, already covered by the resolve_date 'next'/'prev' specs -- keep passing
end)
```
