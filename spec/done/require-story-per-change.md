## **Story: [tech] Require every change to be tied to a story in spec/doing/**

**Use Case:** A few recent changes (test refactors, CLAUDE.md clarifications) were made directly without first creating and moving a story into `spec/doing/`. Without this discipline, work happens outside the tracked workflow, making it harder to see what's in progress and why, and easier to drift from the ways-of-working the project has settled on.

### **Acceptance Criteria**

* **Given** a change is about to be made to the repo (plugin code, tests, or process/tooling docs like CLAUDE.md),
* **When** no existing story in `spec/doing/` covers that change,
* **Then** work stops, a story is created (or an existing backlog/todo story is moved), it's placed in `spec/doing/`, and only then does the change proceed.

### **Busted Test Cases**

This story documents a process rule in CLAUDE.md, not Lua behavior, so there are no busted specs to write. Verify by checking that future changes each have a corresponding story in `spec/doing/` at the time they're made.
