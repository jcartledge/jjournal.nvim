## **Story: [tech] Review CLAUDE.md — separate general principles from project-specific guidance**

**Use Case:** CLAUDE.md has grown incrementally across many stories (ways-of-working, testing conventions, comments conventions) without ever stepping back to look at its overall shape. Some of it is genuinely jjournal.nvim-specific (the `spec/` directory workflow, config key names, the `%D` placeholder rules), while a lot of it is general software-engineering practice that would apply to any project (test-first development, avoiding busted's lifecycle hooks in favor of an explicit setup helper, comments explaining *why* not *what*, docstring vs. inline-comment density). Distilling these into clearly separated general-principles vs. project-specific guidance would make the document easier to navigate, and easier to judge what's safe to reuse elsewhere vs. what's tied to this repo.

### **Acceptance Criteria**

* **Given** the current CLAUDE.md,
* **When** it's reviewed,
* **Then** its content is reorganized into at least two clearly delineated groups: general principles (portable practices, not tied to jjournal.nvim's specifics) and project-specific guidance (the `spec/` workflow, config shape, this repo's own conventions) — exact structure (two sections in one file, vs. a separate general-principles document) to be decided when this is picked up.

* **Given** the reorganization is a chance to read the whole document with fresh eyes,
* **When** it's reviewed,
* **Then** anything found to be missing, stale, contradictory, or worth tightening gets noted (and fixed, or captured as its own follow-up) — not just a mechanical re-sort of the existing text.

### **Open questions — need deciding when this is picked up**

* Does "general principles" become its own file, or just a clearly labeled section within this same CLAUDE.md?
* Is anything missing entirely — e.g. no documented release/versioning process, no contribution guidance — that a fresh read turns up?

### **Busted Test Cases**

Not applicable — this is a documentation reorganization, not plugin behavior. Verification is just: the resulting document reads clearly, general vs. project-specific is unambiguous, and nothing substantive was lost.
