## **Story: [tech] Validate base_dir at setup time, fail clearly instead of a cryptic write-time error**

**Use Case:** `config.file_path` is validated at `setup()` time (a structurally invalid template raises a hard error immediately), but `config.base_dir` is never validated at all -- it's just a string concatenated into paths. If it's genuinely unusable (points at an existing file rather than a directory, or sits somewhere unwritable), the failure doesn't surface until the `BufWritePre` autocmd's `vim.fn.mkdir` call silently fails (its return value isn't checked) and the subsequent `:write` fails with Neovim's own generic `E212` error -- which says nothing about `base_dir`, permissions, or jjournal at all, and can recur on every single write for as long as the misconfiguration stands.

This story adds two different responses, chosen by how reliable each check actually is:

* If `base_dir` already exists as a regular file rather than a directory, that's unambiguous -- no filesystem quirk or timing issue makes this workable -- so it gets the same treatment as an invalid `file_path`: a hard `error()` in `setup()`, before mappings or autocmds bind, so nothing partially works.
* If `base_dir` doesn't exist yet (the common, expected case for a fresh journal) but its nearest existing ancestor directory isn't writable, `setup()` still completes normally (mappings and autocmds bind as usual) but `vim.notify`s a clear, specific `ERROR`-level message naming `base_dir` and the problem. Permission-bit inspection isn't reliable enough across every filesystem/platform (network mounts, containers, ACLs) to risk disabling the whole plugin on a possible false positive -- a wrong warning is a minor annoyance; a wrongly-disabled plugin over a false positive is a much worse outcome for what should have been a working setup.

`config.search`'s validation deliberately stays exactly as it is today (a runtime `vim.notify(WARN)` the moment an invalid value is actually used, not a setup-time check) -- it's not core enough to justify blocking the whole plugin over, and its existing message is already specific enough ("jjournal: unknown search provider '<value>'").

### **Acceptance Criteria**

* **Given** `base_dir` already exists on disk as a regular file (not a directory),
* **When** `setup()` is called,
* **Then** it raises an error immediately and neither mappings nor autocmds are bound.

* **Given** `base_dir` doesn't exist yet, and no existing ancestor directory of it is found to be unwritable,
* **When** `setup()` is called,
* **Then** it completes normally with no warning -- this includes the common case of a brand-new journal whose entire path doesn't exist yet, as long as some ancestor (e.g. `$HOME`) is writable.

* **Given** `base_dir` (or, if it doesn't exist yet, its nearest existing ancestor) is not writable,
* **When** `setup()` is called,
* **Then** it `vim.notify`s a clear `ERROR`-level message naming the path and the problem, but still binds mappings and autocmds normally.

### **Busted Test Cases**

```
it("errors and does not bind mappings/autocmds when base_dir already exists as a file", function() ... end)
it("does not warn when base_dir already exists and is a writable directory", function() ... end)
it("does not warn when base_dir doesn't exist yet but its writable parent does", function() ... end)
it("walks up multiple missing levels to find the nearest existing ancestor", function() ... end)
it("warns but still binds mappings/autocmds when the nearest existing ancestor isn't writable", function() ... end)
```
