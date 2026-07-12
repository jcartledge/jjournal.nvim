## **Story: [tech] Audit other glob/pattern/format-string call sites for real-Neovim behavior**

**Use Case:** `fix-autocmd-pattern-for-flat-layouts.md` (done) found a real, previously-unknown production bug: the autocmd pattern `<base_dir>/**/*<ext>` silently never matched flat (non-nested) journal layouts, because Neovim's `autocmd-pattern` `**` wildcard requires at least one subdirectory -- a quirk `vim.fn.glob()` and `:vimgrep` don't share. That bug went unnoticed because the test suite mocks `nvim_create_autocmd` and invokes the captured callback manually, which never exercises Neovim's own pattern-matching interpretation of the string we hand it. We spot-checked `vim.fn.glob` (used by `dates_from_disk`) and `:vimgrep` (used by `search.lua`'s builtin provider) at the time and confirmed neither shares the bug -- but that was a one-off check for the two call sites we happened to think of, not a systematic pass. Any other place a glob, autocmd pattern, `os.date`/`strftime` format string, or similar Neovim-interpreted value is constructed is a candidate for the same class of blind spot: a mocked test can confirm we built *a* string, never that the string means what we think to Neovim.

### **Acceptance Criteria**

* **Given** every call site in `lua/jjournal/` that constructs a value later interpreted by Neovim itself (autocmd patterns, `vim.fn.glob`/`:vimgrep` patterns, `os.date`/`strftime` format strings, or similar),
* **When** each is reviewed,
* **Then** each either already has a real, unmocked test exercising Neovim's actual interpretation of it (like the two added in `fix-autocmd-pattern-for-flat-layouts.md`), or gets one added if missing.

* **Given** the review turns up no further bugs,
* **When** this story is closed out,
* **Then** it still leaves behind whichever real/unmocked tests were missing, so the coverage of this specific risk class doesn't regress silently later.

### **Busted Test Cases**

Depends entirely on what the audit finds -- if a call site turns out to already be well-covered by a real (unmocked) test, nothing new is needed there; if not, add a real-file/real-Neovim-execution test in the style of the two `register_autocmds` specs added in `fix-autocmd-pattern-for-flat-layouts.md`, with a comment explaining the deliberate deviation from the mock-only convention.
