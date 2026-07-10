## **Story: Default the journal path to nested Y/M directories**

**Use Case:** A flat directory of thousands of `YYYY-MM-DD.md` files gets unwieldy over years of daily use. Most users will want files nested by year and month out of the box, without having to know about or configure `file_path` themselves.

### **Acceptance Criteria**

* **Given** a fresh install with no `file_path` configured,
* **When** setup runs,
* **Then** the default template nests files under year/month directories (e.g. `"%Y/%m/%Y-%m-%d.md"`) instead of the current flat `"%Y-%m-%d.md"`.

* **Given** this is a breaking change to the default file layout,
* **When** it ships,
* **Then** it's documented clearly (README/vimdoc/changelog) so existing users relying on the flat default know to either set `file_path = "%Y-%m-%d.md"` explicitly to keep their current layout, or migrate (see the companion migration story).

### **Busted Test Cases**

```
it("defaults file_path to nested year/month directories", function()
    jjournal.setup({})
    assert.are.equal("/journal/2026/07/2026-07-09.md", jjournal.resolve_path("2026-07-09"))
end)
```
