## **Story: [tech] Consider extracting migration into a separate, more generic plugin**

**Use Case:** Moving files around based on a date embedded in their filename isn't really specific to journaling — the same problem applies to any date-organized file collection (logs, invoices, photos, whatever). Bundling `jjournal.migrate` inside jjournal.nvim ties a potentially generically useful tool to a small, opinionated journaling plugin. Worth a deliberate look, once the migration feature has existed and been used for a while, at whether it (and maybe the underlying date-extraction/path-template-resolution helpers) should live in its own independent plugin instead.

### **Acceptance Criteria**

* **Given** `jjournal.migrate` has existed and been used for some time,
* **When** there's enough signal that the underlying date-in-filename discovery/move logic is broadly useful beyond journaling,
* **Then** evaluate extracting it into a separate plugin — deciding what stays in jjournal.nvim (if anything) versus what moves, and what the new plugin's own interface/scope should be.

This is a research/decision item, not a scoped implementation — revisit and flesh out before acting on it.

### **Busted Test Cases**

None yet — no implementation decided.
