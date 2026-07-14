## **Story: [idea] Plumbing to resolve filename/filepath for a date, so users can BYO link snippets**

**Use Case:** Raised as an idea, refined from an earlier, broader framing that also mentioned backlinks/references (dropped -- not what was meant). The actual scope: jjournal wouldn't provide any link-insertion UI, snippet, or formatting itself -- just the plumbing (date -> filename/path, in the forms someone would actually need) so a user can build their own link-insertion snippet for whatever tool and filetype they use (LuaSnip, nvim-cmp, a plain keymap, whatever). Plumbing, not porcelain -- the same spirit as the existing `search` config accepting a bare function, or `resolve_path` already being public for a calendar-picker integration to call directly.

`resolve_path(date_str)` already exists and is already public, returning the full absolute path for a date. What's likely still missing for building a usable link:

* A path *relative* to something (the current buffer's directory, `base_dir` itself, or cwd) -- markdown/wiki links are usually written relative for portability, not as an absolute filesystem path baked into the note.
* Just the filename/basename for a date, without the full directory prefix -- `path.lua` already has `file_path_basename`/`file_path_extension`, but those operate on the `file_path` *template* string, not a resolved date, and aren't part of the documented public API (`jjournal.path` is reachable via `require`, but nothing in `doc/jjournal.txt`'s Lua API section commits to it as a stable surface).

### **Open questions**

* Exactly which of the above are actually missing versus already achievable today by combining the existing public `resolve_path` with `require("jjournal.path")` directly (undocumented but functional) -- worth auditing what's genuinely absent before designing new API surface.
* Relative to what? Different link tools/filetypes likely want different anchors (current buffer's directory for a portable in-repo link, vs. `base_dir` itself, vs. cwd) -- may need more than one helper, or a parameter, rather than a single fixed answer.
* If `jjournal.path`'s helpers are the right building blocks already, does this story reduce to "promote them to the documented public API" rather than writing new functions at all?
* Would help to have a concrete target case (a specific snippet engine + filetype) to validate the resulting API's ergonomics against, rather than guessing at a shape in the abstract.

### **Acceptance Criteria**

TBD -- not yet scoped; needs the "what's actually missing" audit above before concrete Given/When/Then criteria.

### **Busted Test Cases**

TBD.
