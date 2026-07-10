## **Story: [tech] Clean up the stub/mock lint warning and add linting to the test workflow**

**Use Case:** Neovim's "Lua Diagnostics" (almost certainly `lua_ls`, based on the source label) flags an "undefined field" warning on every line in the test suite that reads a stub/mock's call record (`.calls`, `.was_called(...)`, `.was_called_with(...)`, etc. — anywhere a stub/spy object from `luassert` is used). This happens because `luassert`'s stub/spy return shape has no type annotations `lua_ls` knows about, so it can't tell those fields exist — it's noise, not a real bug, but it's noise on nearly every assertion in `tests/jjournal_spec.lua`. Separately, no linter of any kind currently runs as part of `./tests/scripts/run.sh` or anywhere else automated, so this and any future lint issue only surface if someone happens to have their editor open and notices.

Since the `init.lua` module-split refactor (see `restructure-init-lua-into-modules.md`), all interfaces — public and private/internal — are annotated with LuaCATS (`---@param`/`---@return`) comments for `lua_ls` to check. Whichever tool this story settles on should also verify those annotations are actually being enforced (a deliberately wrong `---@param` type should surface as a lint failure), not just that the stub/mock warning is silenced — otherwise the annotations are documentation-only and can drift unnoticed.

### **Acceptance Criteria**

* **Given** the stub/mock call-record fields (`.calls`, `.was_called`, etc.) used throughout `tests/jjournal_spec.lua`,
* **When** `lua_ls` (or whichever tool this turns out to be) analyzes the test suite,
* **Then** it no longer reports "undefined field" for these — likely via type annotations for `luassert`'s stub/spy shape (inline `---@class`/`---@field` comments, a small hand-written type definition file added to `.luarc.json`'s `workspace.library`, or scoped `---@diagnostic disable` comments if annotating the real shape isn't practical) — whichever approach doesn't just blanket-suppress the `undefined-field` check everywhere and lose its value for genuine mistakes elsewhere.

* **Given** `./tests/scripts/run.sh` (or a sibling script) is run,
* **When** it executes,
* **Then** it also lints both `lua/` and `tests/`, and fails (non-zero exit) if linting reports problems — the same "don't silently let this regress" principle already applied to test coverage.

### **Open questions — need deciding when this is picked up**

* **Which linter actually runs in CI/local scripts?** `lua_ls` is an LSP, primarily interactive; it does have a headless `--check <dir>` mode that could plausibly be scripted, but that's a heavier dependency (the language server binary) than a standalone CLI linter. `selene` and `luacheck` are lighter-weight, script-friendly alternatives, but neither does `lua_ls`'s style of type inference — they likely wouldn't have caught this specific "undefined field on a stub's return value" issue in the first place, since that requires understanding the *shape* of what `stub()` returns, not just syntax/style/global-usage checks. Confirm which tool(s) actually catch what before committing to one, rather than assuming CLI-linter parity with what the editor currently reports.
* **Does fixing the annotation gap fully resolve the warning, or is some scoped suppression still needed** for parts of the stub API that are awkward to type accurately (e.g. `luassert.stub`'s dynamic call-count/argument-list behavior)?

### **Busted Test Cases**

Not applicable — this is a tooling/lint change, not plugin behavior. Verify by confirming the warning is gone in the editor and that the chosen linter step in `./tests/scripts/run.sh` (or sibling script) exits non-zero when a lint issue is deliberately introduced, then passes once it's fixed.
