## **Story: [idea] A separate "recipes" repo/plugin, rather than growing README recipes indefinitely**

**Use Case:** Raised as an open idea, not scoped: "some way of handling recipes -- maybe a separate plugin that contains recipes you can easily reuse for configuring snippets, statusline etc." The README already carries two fairly detailed Heirline/AstroNvim recipes (statusline, tabline) plus a lualine pointer, and the composability draft sketches several more potential integrations (search providers, linking, templating). Continuing to grow README prose for every new integration doesn't scale well, and prose recipes require copy-pasting Lua by hand rather than something requirable/reusable directly.

The alternative: a separate, optional companion repo containing actual reusable Lua (statusline component builders, snippet definitions, etc.) that depends on jjournal's public API/buffer-local vars/`User` events, versioned and installed independently -- rather than anything living in jjournal.nvim itself.

**Note:** this is fundamentally a project-structure/ecosystem decision (a *new repository*), not a code change within jjournal.nvim -- doesn't fit this repo's usual story shape (no acceptance criteria expressible as behavior of *this* codebase, no busted specs possible). Recording it here anyway since it's directly relevant to how jjournal's own composability documentation should evolve, and because deciding "recipes stay in README as prose" vs. "recipes move to reusable code in a companion repo" affects how the composability draft doc and any future recipe stories (linking plumbing, etc.) should be written.

### **Open questions**

* Is README prose actually a problem yet, or premature to solve -- currently two recipes plus pointers, not obviously unwieldy yet.
* If pursued, what's the actual maintenance/versioning story -- does a companion repo need to track jjournal's own version compatibility, and who's expected to maintain it as jjournal's public API evolves?
* Would this cannibalize the composability draft doc's purpose (which is explanatory/illustrative) if recipes become literal requirable code instead of "here's an example to adapt to your own config" -- these might be two different, both-worth-having things (a doc that explains *why* and *what's possible*, plus optional code that shortcuts the *how*) rather than one replacing the other.

### **Acceptance Criteria**

N/A -- not a jjournal.nvim code change; a project-structure question to resolve before it becomes actionable at all.

### **Busted Test Cases**

N/A.
