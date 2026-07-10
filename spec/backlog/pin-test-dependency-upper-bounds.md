## **Story: [tech] Pin upper bounds for test dependencies**

**Use Case:** `test_dependencies` in `jjournal-dev-1.rockspec` use `>=` constraints with no upper bound (`busted >= 2.2.0`, `luacov >= 0.15.0`, etc.). A future major-version release of any of these could break local test runs or CI without warning, since LuaRocks will happily install the newest available version.

### **Acceptance Criteria**

* **Given** `test_dependencies` in the rockspec,
* **When** the versions are reviewed,
* **Then** each dependency has both a lower and upper bound reflecting the range currently verified to work (e.g. `busted >= 2.2.0, < 3.0.0`).

### **Busted Test Cases**

This story only changes version constraints in the rockspec, not Lua behavior, so there are no new busted specs to write. Verify by running `luarocks test --tree=.rocks` (or `./tests/scripts/run.sh` with a fresh `.rocks` tree) and confirming the full suite still passes with the pinned versions.
