## **Story: setup_test runs the test body and cleans up automatically**

**Use Case:** `setup_test` returns a `cleanup` function that a test must remember to call. If a test forgets, or returns early (e.g. an assertion fails and throws before `cleanup()` is reached), stubs and the `jjournal.config` restore from that test leak into every test that runs after it — the exact class of bug just found and fixed by hand in `configurable-journal-path-template`. Changing the calling convention to `setup_test(mocks, function() <test body> end)` — passing the test body in as a callback, which `setup_test` invokes and then always cleans up after (even if the callback throws) — makes correct cleanup an invariant of the calling convention itself, not something each test has to remember.

### **Acceptance Criteria**

* **Given** a test calls `setup_test(mocks, function() <test body> end)`,
* **When** the callback returns normally,
* **Then** `setup_test` installs the requested mocks, runs the callback, and always runs cleanup (config restore + stub revert) afterward — the caller never sees or calls a separate `cleanup` function.

* **Given** the callback raises an error (e.g. a failed assertion),
* **When** `setup_test` runs it,
* **Then** cleanup still runs before the error propagates, so a failing test doesn't leak stub/config state into subsequent tests.

### **Busted Test Cases**

This changes `tests/support/setup_test.lua` itself, which isn't part of jjournal's public interface, so there's no busted spec pinning jjournal behavior. Verify by refactoring every call site in `tests/jjournal_spec.lua` to the callback form and confirming the suite still passes with full coverage; consider adding a small spec directly against `setup_test` (e.g. via `pcall`) asserting cleanup runs even when the callback errors.
