## **Story: [tech] Add vimdoc user docs; keep README.md as dev docs**

**Use Case:** README.md currently mixes end-user content (installation, config options, default keymaps) with developer content (running tests, project structure, ways of working). Neovim plugins conventionally document end-user usage as a `:help` page (`doc/jjournal.txt`) so users can look things up from inside the editor without leaving it or finding the right file on GitHub. Splitting these lets README.md focus purely on contributing to the project, and gives users a proper `:help jjournal`.

### **Acceptance Criteria**

* **Given** the plugin is installed and helptags are generated (`:helptags ALL` or handled automatically by the user's plugin manager),
* **When** a user runs `:help jjournal`,
* **Then** they see documentation covering `setup()`, each config option (`path`, `use_default_mappings`, `search`), the default keymaps, and how backlog search provider selection works.

* **Given** `doc/jjournal.txt` exists,
* **When** it's inspected,
* **Then** it follows standard vimdoc conventions: a mode line, a tags-and-table-of-contents header, `*jjournal-topic*` style tags for each section, and column-79 wrapping.

* **Given** README.md after this change,
* **When** a contributor reads it,
* **Then** it covers only development concerns (setup, testing, project structure, ways of working) and points to `:help jjournal` for end-user usage instead of duplicating it.

### **Busted Test Cases**

This story adds a vimdoc help file and trims README.md — no Lua behavior changes, so there are no busted specs to write. Verify by running `:helptags` on the `doc/` directory and confirming `:help jjournal` renders correctly with working tag links, and by confirming README.md no longer duplicates the config/keymap details now living in `doc/jjournal.txt`.
