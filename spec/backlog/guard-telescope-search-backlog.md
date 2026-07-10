## **Story: [tech] Guard search_backlog against a missing telescope dependency**

**Use Case:** `M.search_backlog` calls `require("telescope.builtin")` unconditionally. If a user triggers `<leader>fj` without telescope installed, they get a raw "module not found" error instead of a clear explanation of what's missing.

### **Acceptance Criteria**

* **Given** `telescope.builtin` is not available,
* **When** `search_backlog` (or the `<leader>fj` mapping) is triggered,
* **Then** a clear `vim.notify` warning explaining that telescope is required is shown, instead of an uncaught Lua error.
* **Given** `telescope.builtin` is available,
* **When** `search_backlog` is triggered,
* **Then** it behaves exactly as it does today (delegates to `live_grep` with the configured path).

### **Busted Test Cases**

```
it("warns instead of erroring when telescope.builtin is not available", function()
    -- ensure package.loaded["telescope.builtin"] is nil and require() for it fails,
    -- stub vim.notify, call jjournal.search_backlog(),
    -- assert vim.notify was called with a WARN level message and no error was raised
end)

it("still delegates to live_grep when telescope.builtin is available", function()
    -- existing behavior, already covered by
    -- "delegates to telescope's live_grep with the configured path" -- keep passing
end)
```
