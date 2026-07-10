## **Story 2: Recycle and auto-clean unedited future journal buffers**

**Use Case:** When stepping through future dates, you want to view them without permanently filling up your Neovim buffer list (`:ls`) or creating empty files on your disk. Unedited future buffers should behave like temporary previews that disappear when you navigate away, but persist if you type into them.

### **Acceptance Criteria**

* **Given** a new journal buffer is spawned via future navigation,  
* **Then** it is initially flagged as a temporary preview buffer.  
* **When** I navigate forward again while in a preview buffer,  
* **Then** the system reuses the *same* buffer ID, updating only its file name and text content for the new date.  
* **When** I navigate completely away from a preview buffer while it is still unmodified,  
* **Then** the buffer is completely wiped out (`bwipeout`) from Neovim's memory and no file is written to disk.  
* **When** a preview buffer detects any text mutation (`TextChanged` or `InsertEnter`),  
* **Then** the preview flag is stripped, making it a standard persistent buffer that remains loaded when left.

### **Busted Test Cases**

```
it("reuses the same buffer ID when consecutively viewing untouched future dates", function()
    jjournal.navigate_to("2026-07-15")
    local original_buf = vim.api.nvim_get_current_buf()
    assert.is_true(vim.b[original_buf].jjournal_preview)
    
    jjournal.step_future()
    local next_buf = vim.api.nvim_get_current_buf()
    
    assert.are.equal(original_buf, next_buf)
end)

it("wipes out a future buffer entirely if navigated away from without edits", function()
    jjournal.navigate_to("2026-07-15")
    local target_buf = vim.api.nvim_get_current_buf()
    
    jjournal.navigate_to_today()
    
    assert.is_false(vim.api.nvim_buf_is_valid(target_buf))
end)

it("preserves the buffer and removes preview status upon user modification", function()
    jjournal.navigate_to("2026-07-15")
    local target_buf = vim.api.nvim_get_current_buf()
    
    vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { "- [ ] Future roadmap item" })
    vim.cmd("doautocmd TextChanged")
    
    assert.is_nil(vim.b[target_buf].jjournal_preview)
    
    jjournal.navigate_to_today()
    assert.is_true(vim.api.nvim_buf_is_valid(target_buf))
end)
```
