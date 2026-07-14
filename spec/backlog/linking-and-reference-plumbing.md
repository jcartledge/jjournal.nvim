## **Story: [idea] Plumbing for linking to (and referencing from) journal entries**

**Use Case:** Raised as a fuzzy, not-yet-scoped idea: "plumbing to enable quickly linking to journal pages eg with snippets -- not providing the snippets directly. And not just linking but references?" jjournal wouldn't ship actual snippets/UI -- the composability draft's philosophy is that jjournal exposes small, stable seams (buffer-local vars, a `User` autocmd, a public Lua API) that other tooling (LuaSnip, nvim-cmp, vim-waikiki) builds on, the same way `resolve_path(date_str)` is already public and usable by a calendar-picker integration.

This idea actually bundles two different things that likely need to be told apart before either is scoped:

* **Linking** (probably the smaller piece): given a date, produce the right link text to *insert* -- a markdown link or wiki-link pointing at that entry, correctly formed from whatever `file_path` template is actually configured (so it stays correct across flat/nested layouts, custom extensions, etc.). Plausibly just a thin new public function (e.g. something like `M.link_to(date_str)` returning a formatted string) that a snippet engine calls, alongside `resolve_path` and the rest of the existing public API.
* **References** (probably materially bigger): showing which *other* entries link back to the one you're currently in -- an Obsidian-style "linked mentions" / backlink index. This would need scanning/indexing other files for references pointing at the current one, not just formatting an outgoing link -- a meaningfully different (and bigger) feature than link-insertion, more like a lightweight knowledge-graph than a navigation convenience.

### **Open questions**

* Should these be two separate stories once either is pursued, rather than one -- they have very different scope and "references" in particular might not belong in jjournal's own remit (a plugin's-worth of scope on its own) versus something better left to a dedicated wiki/notes plugin that happens to compose with jjournal via its public API, the way vim-waikiki already does today for plain navigation.
* What "linking" format should the plumbing target -- markdown links, wiki-link `[[...]]` syntax, both, configurable? Depends partly on what `file_path`/extension the user has configured.
* Is a backlink index even feasible without maintaining persistent state across sessions (a cache/index file), which would be a first for jjournal -- currently everything is computed on demand from disk/buffers with no persisted index of its own (`dates.lua`'s `dates_from_disk`/`dates_from_buffers` are recomputed each call, nothing cached to a file).

### **Acceptance Criteria**

TBD -- not yet scoped; needs splitting into (at minimum) a separate linking story and references story before either has concrete criteria.

### **Busted Test Cases**

TBD.
