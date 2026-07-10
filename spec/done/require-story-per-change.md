## **Story: [tech] Require every change to be tied to a story in spec/doing/**

**Use Case:** A few recent changes (test refactors, CLAUDE.md clarifications) were made directly without first creating and moving a story into `spec/doing/`. Without this discipline, work happens outside the tracked workflow, making it harder to see what's in progress and why, and easier to drift from the ways-of-working the project has settled on.

### **Acceptance Criteria**

* **Given** a change is about to be made to the repo (plugin code, tests, or process/tooling docs like CLAUDE.md),
* **When** no existing story in `spec/doing/` covers that change,
* **Then** work stops, a story is created (or an existing backlog/todo story is moved), it's placed in `spec/doing/`, and only then does the change proceed.

### **Busted Test Cases**

This story documents a process rule in CLAUDE.md, not Lua behavior, so there are no busted specs to write. Verify by checking that future changes each have a corresponding story in `spec/doing/` at the time they're made.

---

### **Revision 1: Exceptions for backlog additions and rework of closed stories**

**Use Case:** The original rule didn't account for two common cases: (1) adding new stories to the backlog is planning, not a change — requiring a story in order to add a story is circular; (2) when new work clearly reworks something already delivered, editing the closed story's original content would erase the record of what was actually built and delivered.

### **Acceptance Criteria**

* **Given** stories are being added to `spec/backlog/` (not `spec/doing/` work itself),
* **When** this happens,
* **Then** it can happen at any time without a story of its own — planning isn't a change that requires a story.

* **Given** a story is currently in `spec/doing/`,
* **When** new stories are identified as a direct byproduct of that work (deferred edge cases, a bug spotted while implementing, a related future enhancement),
* **Then** those stories can be added to `spec/backlog/` while the original story is still in `doing/`. Otherwise (i.e. unrelated new backlog stories), adding stories should normally happen when nothing is in `doing/`.

* **Given** new work clearly reworks or extends a story already in `spec/done/`,
* **When** that story is picked back up,
* **Then** the file is moved back into `spec/doing/` and a new section is appended describing the changed requirement — the original Use Case/Acceptance Criteria/Busted Test Cases describing what was already delivered are left untouched, not edited.

### **Busted Test Cases**

Process rule, not Lua behavior — no busted specs. Verified in practice: this revision was made by moving this file back into `spec/doing/` and appending this section, rather than editing the original content above.
