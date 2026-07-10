## **Story 3: Make journal file path configurable with date format placeholders**

**Use Case:** You want the flexibility to structure your journal file system (e.g., nesting by year/month folders or using custom naming conventions) rather than a rigid flat file structure. This requires defining a template string with placeholders like %Y, %m, and %d.

### **Acceptance Criteria**

* **Given** I have configured a custom journal path template,  
* **When** I navigate to a date,  
* **Then** the system resolves the template string by replacing date format placeholders (e.g., `journal/%Y/%m/%d.md`) with the actual date values before opening the file.

### **Busted Test Cases**

```
it("resolves the file path template using date format placeholders", function()
    local template = "journal/%Y/%m/%d.md"
    jjournal.setup({ path_template = template })
    
    local expected_path = "journal/2026/07/09.md"
    local resolved_path = jjournal.resolve_path("2026-07-09")
    
    assert.are.equal(expected_path, resolved_path)
end)
```
