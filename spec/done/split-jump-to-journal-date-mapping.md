## **Story 5: Add a split variant of the jump-to-date mapping**

**Use Case:** `<leader>jj` prompts for a date and opens it in the current window. You also want a split variant, consistent with the existing edit/split pairs (`gj`/`gJ`, `[j`/`[J`, `]j`/`]J`), so you can jump to an arbitrary date in a vertical split without disturbing your current buffer.

### **Acceptance Criteria**

* **Given** default mappings are enabled,
* **When** I trigger `<leader>jJ`,
* **Then** I am prompted for a date and, once entered, that journal entry opens in a vertical split (`vsplit`) rather than replacing the current window.

### **Busted Test Cases**

```
it("binds <leader>jJ to prompt for a date and open it in a vsplit", function()
    -- stub vim.keymap.set, call jjournal.setup({ use_default_mappings = true }),
    -- assert vim.keymap.set was called for "<leader>jJ" with a handler that
    -- resolves target = "prompt" and opens with cmd = "vsplit"
end)

it("prompts for a date and opens the result in a split when <leader>jJ is triggered", function()
    -- stub vim.ui.input to invoke its callback with "2026-07-09",
    -- stub vim.cmd, call jjournal.execute("prompt", "vsplit"),
    -- assert vim.cmd was called with "vsplit .../2026-07-09.md"
end)
```
