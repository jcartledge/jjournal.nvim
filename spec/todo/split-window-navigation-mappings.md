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

## **Story: Remove all split/vsplit-variant navigation mappings**

**Use Case:** Window management (opening a result in a vertical split vs. the current window) is generic Vim behavior — splitting first (`<C-w>v`) then invoking the plain mapping already produces the identical end state as a dedicated vsplit mapping, since `:edit path` run inside a freshly split window has the same effect as `:vsplit path` run from the original one. Baking a split variant into every navigation mapping doubles the mapping surface (`gj`/`gJ`, `[j`/`[J`, `]j`/`]J`, `<leader>jj`/`<leader>jJ`) for a convenience Vim already provides generically — and that doubling is specifically what forces an awkward mapping grammar once step and skip become separate modes (see `step-and-skip-navigation-modes.md`). Removing it decouples window management from navigation-mode design entirely.

We're pre-release, so this is a straightforward removal, not a deprecation cycle.

### **Acceptance Criteria**

* **Given** the default mappings,
* **When** `setup()` binds them,
* **Then** `gJ`, `[J`, `]J`, and `<leader>jJ` no longer exist — only their edit-mode equivalents remain (`gj`, `<leader>jj`, plus whatever `next`/`prev` end up named per `step-and-skip-navigation-modes.md`).

* **Given** `M.execute`/`M.resolve_date`/`M.open_date`'s public `cmd` parameter,
* **When** this change lands,
* **Then** it's untouched — anyone wiring their own mapping can still pass `"vsplit"` explicitly; only the *shipped default* mappings for split variants are removed.

* **Given** README.md and doc/jjournal.txt currently document the split mappings and the edit/split pairing convention,
* **When** this change lands,
* **Then** both are updated to remove those entries, noting the `<C-w>v` + plain-mapping idiom as the replacement if useful.

### **Busted Test Cases**

```
it("no longer binds gJ, [J, ]J, or <leader>jJ", function()
    -- setup with use_default_mappings = true, keymap.set stubbed
    -- assert none of these four keys appear in any vim.keymap.set call
end)
```

Existing specs to remove outright (not adaptable, since the mappings themselves go away):
* "includes a <leader>jJ mapping that prompts for a date and opens it in a vsplit"
* the "binds <leader>jJ..." Busted Test Case sketched in this file's original section above

`execute`/`open_date` honoring `cmd = "vsplit"` when called directly stays fully valid and tested elsewhere — only the *default keybinding* for it goes away, not the underlying capability.
