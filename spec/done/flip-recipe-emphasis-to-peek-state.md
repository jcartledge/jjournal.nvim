## **Story: [docs] Flip the statusline/tabline recipes to highlight the peek/unpinned state, not pinned**

**Use Case:** The README's Heirline statusline and tabline recipes currently show 📌 only when a buffer is pinned, with no decoration otherwise. But with the current pin model (editing a buffer auto-pins it permanently, on top of the explicit `<leader>jp` toggle), *pinned* quickly becomes the common, eventual state for anything actually engaged with in a session -- only a genuine drive-by look (browsing history without touching it) stays unpinned. Highlighting the less common, more actionable state -- "this buffer is just a peek and will vanish if you navigate away without touching it" -- is more useful signal than highlighting the state most buffers end up in anyway.

Not a new buffer state: the same `vim.b.jjournal_pinned` boolean as today, just flipping which value gets a visual decoration in the recipe examples. `jjournal.pin_buffer()` itself (the `User JjournalPinned` autocmd, `:redrawstatus`) is unaffected -- purely a recipe change.

Icon: 👁 (eye), chosen for "observing, not committing" -- open to alternatives (e.g. 👻/💨 lean more into the impermanence itself) but no strong reason to change it.

### **Acceptance Criteria**

* **Given** the README's statusline recipe,
* **When** `vim.b[0].jjournal_pinned` is falsy,
* **Then** the component shows 👁 instead of nothing; when truthy, it shows nothing instead of 📌.

* **Given** the README's tabline recipe,
* **When** `vim.b[self.bufnr].jjournal_pinned` is falsy for a given buffer,
* **Then** that buffer's entry shows 👁 instead of nothing; when truthy, it shows nothing.

* **Given** `doc/jjournal.txt`'s buffer-status prose,
* **When** read alongside the updated recipes,
* **Then** it no longer implies the old "decoration only when pinned" default, matching what the recipes actually show.

### **Busted Test Cases**

N/A -- documentation/recipe-only change, no jjournal Lua behavior changes (same precedent as `tabline-pin-indicator-recipe.md`).
