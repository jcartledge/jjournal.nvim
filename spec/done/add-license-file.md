## **Story: [tech] Add a LICENSE file matching the rockspec's MIT declaration**

**Use Case:** `jjournal-dev-1.rockspec` declares `license = "MIT"`, but there's no actual LICENSE file in the repo. This is ambiguous for anyone consuming the plugin via LuaRocks, a plugin manager, or a fork/redistribution.

### **Acceptance Criteria**

* **Given** the rockspec declares an MIT license,
* **When** someone inspects the repository root,
* **Then** a `LICENSE` file containing the standard MIT license text (with the correct copyright holder/year) is present.

### **Busted Test Cases**

This story adds a static license file, not Lua behavior, so there are no busted specs to write. Verify by confirming `LICENSE` exists at the repo root and its text matches the standard MIT license.
