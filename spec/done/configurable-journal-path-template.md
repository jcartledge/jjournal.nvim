## **Story: Make journal file path configurable with date format placeholders**

**Use Case:** You want the flexibility to structure your journal file system (e.g., nesting by year/month folders, custom filenames, or non-markdown extensions) rather than a rigid flat file structure. This requires defining a template string relative to `base_dir`, built from date placeholders.

### **Acceptance Criteria**

* **Given** I have configured `file_path` (e.g. `"%Y/%m/%Y-%m-%d.md"` or `"%Y/%m/%d/journal-%D.txt"`),
* **When** I navigate to a date,
* **Then** `jjournal.resolve_path(date_str)` replaces `%Y`, `%m`, `%d` with the year/month/day of `date_str`, replaces `%D` with the full `date_str` (shorthand for `%Y-%m-%d` used together), and returns the result appended to `base_dir` — and this is the path actually opened/created by `open_date` and compared against by the today/archive autocmd.

* **Given** `file_path` is not configured,
* **When** setup runs,
* **Then** it defaults to `"%Y-%m-%d.md"`, reproducing the existing flat file layout exactly.

* **Given** a configured `file_path` whose filename portion (the segment after the last `/`) does not contain `%D` and does not contain the literal sequence `%Y-%m-%d`,
* **When** `setup` runs,
* **Then** setup raises an error, since navigation depends on recovering a unique full date from the filename alone. The filename may have any prefix, suffix, or extension (or none) as long as it contains one of those two forms — e.g. `"journal-%D.txt"` and `"%Y-%m-%d-notes"` are both valid; `"%Y/%m/%d.md"` (day only, no full date in the filename) is not.

* **Given** journal files exist nested under `base_dir` (per a custom `file_path`) with arbitrary filename prefixes/suffixes and extensions,
* **When** navigating (`gj`, `[j`, `]j`, etc.) or the today/archive autocmd runs,
* **Then** discovery (from disk and from loaded buffers) recurses into subdirectories and identifies each file's date by extracting the `YYYY-MM-DD` substring from its filename, rather than requiring the filename to equal `YYYY-MM-DD.md` exactly.

* **Given** a buffer open somewhere under a nested `base_dir`,
* **When** determining the current navigation anchor,
* **Then** the buffer is treated as "inside the journal" if its directory is `base_dir` itself or a descendant of it (not only if it's exactly equal to `base_dir`).

* **Given** `file_path`'s filename portion ends in an extension (e.g. `.txt`),
* **When** the today/archive autocmd registers its pattern, or `config.search = "builtin"` runs its vimgrep,
* **Then** both match that extension recursively (not the hardcoded `.md` of the previous flat-only implementation).

### **Busted Test Cases**

```
it("resolves the default template the same as the previous flat layout", function()
    jjournal.setup({ base_dir = "/journal/" })
    assert.are.equal("/journal/2026-07-09.md", jjournal.resolve_path("2026-07-09"))
end)

it("resolves %Y/%m/%d placeholders against a nested template", function()
    jjournal.setup({ base_dir = "/journal/", file_path = "%Y/%m/%Y-%m-%d.md" })
    assert.are.equal("/journal/2026/07/2026-07-09.md", jjournal.resolve_path("2026-07-09"))
end)

it("resolves %D as shorthand for the full date alongside %Y/%m/%d", function()
    jjournal.setup({ base_dir = "/journal/", file_path = "%Y/%m/%d/journal-%D.txt" })
    assert.are.equal("/journal/2026/07/09/journal-2026-07-09.txt", jjournal.resolve_path("2026-07-09"))
end)

it("errors when the filename portion has no way to recover the full date", function()
    assert.has_error(function()
        jjournal.setup({ file_path = "%Y/%m/%d.md" })
    end)
end)

it("finds nested, non-.md journal files on disk by extracting the date from the filename", function()
    -- fn.glob mocked to return nested full paths like ".../2026/07/journal-2026-07-09.txt"
    -- assert navigation lands on the extracted date, not the literal filename
end)
```
