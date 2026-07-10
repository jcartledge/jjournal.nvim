## **Story: [tech] Add a pre-commit routine for project hygiene**

**Use Case:** Right now, nothing stops a commit that breaks tests, drops coverage, or leaves two stories in `spec/doing/` at once (our ways-of-working rule that only one story should be in progress at a time). Catching these at commit time, rather than relying on CI or manual discipline, gives faster feedback. Since git doesn't version `.git/hooks` directly, this needs a checked-in hook script plus a one-time setup step (`git config core.hooksPath <dir>`) documented for contributors.

### **Acceptance Criteria**

* **Given** a commit is being made,
* **When** the pre-commit hook runs,
* **Then** it runs `./tests/scripts/run.sh` and blocks the commit (non-zero exit, clear message) if tests fail or coverage is incomplete.

* **Given** more than one story file exists under `spec/doing/`,
* **When** the pre-commit hook runs,
* **Then** it blocks the commit with a message pointing at CLAUDE.md's "only one story in `doing/` at a time" rule.

* **Given** tests pass, coverage is complete, and `spec/doing/` has at most one story,
* **When** the pre-commit hook runs,
* **Then** the commit proceeds normally.

* **Given** a contributor has just cloned the repo,
* **When** they follow the setup instructions (e.g. in README.md),
* **Then** a single documented command installs the hook (e.g. `git config core.hooksPath scripts/hooks`).

### **Busted Test Cases**

This story adds a git hook (shell script) and setup documentation, not Lua behavior, so there are no busted specs to write. Verify manually: stage a commit with a failing test and confirm it's blocked; stage a commit with two files in `spec/doing/` and confirm it's blocked; fix both and confirm a clean commit succeeds.
