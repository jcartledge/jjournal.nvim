## **Story 1: Skip empty days when browsing past entries, step sequentially when targeting future dates**

**Use Case:** When looking at past entries, you want to skip empty days so you can read previous logs without clicking through dates where nothing was written. When navigating into the future, you want to step day-by-day linearly so you can easily target a specific upcoming date to add a task or note.

### **Acceptance Criteria**

* **Given** I am in a journal buffer,  
* **When** I trigger past navigation (`[j`),  
* **Then** the system jumps straight to the closest *existing* past journal entry, skipping empty dates.  
* **When** I trigger future navigation (`]j`),  
* **Then** the system increments the calendar by exactly 1 day and opens that date, even if no file exists on disk for it yet.

### **Busted Test Cases**

```
it("skips empty days when navigating backward into history", function()
    setup_existing_journal("2026-07-06") -- Monday
    jjournal.navigate_to("2026-07-09")   -- Thursday
    
    jjournal.step_past()
    
    assert.are.equal("2026-07-06", jjournal.get_current_date())
end)

it("steps sequentially day-by-day when navigating into the future", function()
    jjournal.navigate_to("2026-07-09") -- Thursday
    
    jjournal.step_future()
    
    assert.are.equal("2026-07-10", jjournal.get_current_date())
end)
```
