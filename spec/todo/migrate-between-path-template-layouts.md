## **Story: Provide a migration path between file_path layouts**

**Use Case:** A user with an existing flat (or otherwise-structured) journal wants to switch `file_path` (e.g. to adopt nested Y/M directories) without losing navigation over, or manually relocating, years of existing entries.

### **Acceptance Criteria**

* **Given** existing journal files on disk that match the OLD `file_path`,
* **When** the user runs a migration command/function after changing `file_path` to a NEW value,
* **Then** each file is moved from its old resolved path to its new resolved path (extracting its date, then re-resolving via the new template), creating any new directories needed and leaving no file behind.

* **Given** a migration is about to overwrite an existing file at a destination path,
* **When** the migration runs,
* **Then** it refuses (or prompts) rather than silently clobbering data.

* **Given** a migration partially fails partway through,
* **When** this happens,
* **Then** the user is told exactly which files were moved and which weren't, so they can retry or fix up manually without guessing.

### **Busted Test Cases**

```
it("moves files from their old resolved location to their new one", function()
    -- setup with old file_path, discover files, change config, run migrate,
    -- assert vim.fn.rename (or mkdir+rename) called old_path -> new_path for each
end)

it("refuses to overwrite an existing file at the destination", function()
    -- destination path already exists on disk -> migration reports/skips it, doesn't rename over it
end)
```
