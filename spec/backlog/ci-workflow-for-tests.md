## **Story: [tech] Add CI to run the test suite on push/PR**

**Use Case:** The busted suite is solid (100% coverage) but only runs when someone remembers to run `./tests/scripts/run.sh` locally. A broken change can currently land on `main` unnoticed. Running the suite automatically on every push/PR catches regressions before they merge.

### **Acceptance Criteria**

* **Given** a commit is pushed or a pull request is opened against the repo,
* **When** CI runs,
* **Then** it installs Neovim and LuaRocks, runs `./tests/scripts/run.sh`, and reports a failing build if any test fails or errors.

### **Busted Test Cases**

This story adds CI configuration (e.g. a GitHub Actions workflow), not Lua behavior, so there are no busted specs to write. Verify by pushing a commit (including one with a deliberately broken test) and confirming the workflow runs and reports the correct pass/fail status.
