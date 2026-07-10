## **Story: [tech] Fail the test run when coverage is under 100%**

**Use Case:** CLAUDE.md states we aim for 100% test coverage, but `./tests/scripts/run.sh` only prints the coverage summary — it doesn't fail the build if coverage drops below 100%. Nothing currently stops a change (or a future test deletion) from silently reducing coverage while `./tests/scripts/run.sh` still reports success. This also underpins the CI story: once CI runs this script, a coverage regression should fail the build the same way a failing test does.

### **Acceptance Criteria**

* **Given** all busted tests pass but line coverage (per `luacov.report.out`'s `LH`/`LF` totals) is below 100%,
* **When** `./tests/scripts/run.sh` completes,
* **Then** it still prints the coverage summary, but exits with a non-zero status.

* **Given** all busted tests pass and line coverage is 100%,
* **When** `./tests/scripts/run.sh` completes,
* **Then** it exits 0, as it does today.

* **Given** busted tests fail (regardless of coverage),
* **When** `./tests/scripts/run.sh` completes,
* **Then** it exits non-zero, as it does today (this behavior must not regress).

### **Busted Test Cases**

This story changes `tests/scripts/run.sh` (a shell script), not Lua behavior, so there are no busted specs to write. Verify by temporarily commenting out a test to drop coverage below 100% and confirming the script exits non-zero, then restoring it and confirming a clean 100%-coverage run exits 0.
