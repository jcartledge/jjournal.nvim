## **Story: Support count-prefixed step/skip navigation ([jj/]jj/[j/]j)**

**Use Case:** No count-handling exists today: `vim.keymap.set`'s callback ignores `v:count` entirely, so pressing `3]jj` behaves identically to a single `]jj` — a natural, idiomatic Vim expectation (repeatable normal-mode motions) that's currently just missing.

Now that step and skip are two separate, always-consistent primitives (see `step-and-skip-navigation-modes.md`), a count has one unambiguous meaning for each, in either direction, regardless of today: for step (`[jj`/`]jj`), N calendar days instead of one. For skip (`[j`/`]j`), the Nth existing entry in that direction instead of the nearest one. Neither depends on where today falls, so the past-direction ambiguity the original version of this story left open no longer exists — it was purely an artifact of the now-removed today-relative fork.

### **Acceptance Criteria**

* **Given** `]jj`/`[jj` are pressed with a numeric count prefix (e.g. `3]jj`),
* **When** triggered,
* **Then** it shifts exactly that many calendar days in that direction and opens the result, creating it if needed.

* **Given** `]j`/`[j` are pressed with a numeric count prefix (e.g. `3]j`),
* **When** triggered,
* **Then** it jumps to the Nth existing entry (on disk or in an open buffer) in that direction, not just the nearest one.

* **Given** no count prefix is given,
* **When** any of `]jj`/`[jj`/`]j`/`[j` are pressed,
* **Then** behavior is unchanged from today (a count of 1, matching Neovim's own `v:count1` default).

* **Given** a count prefix on `gj`/`<leader>jj`/`<leader>fj`,
* **When** any of those are pressed,
* **Then** the count is ignored — it has no defined meaning for "today", "prompt", or "search" targets.

* **Given** `M.execute`/`M.resolve_date` are called directly (e.g. by a user with `use_default_mappings = false` wiring their own mappings),
* **When** a count matters to them,
* **Then** both accept it as a new optional trailing parameter (defaulting to 1 when omitted) — mirroring `vim.v.count1`, which is what the default mapping wrapper reads and passes through — so this isn't only reachable via the built-in mappings.

* **Given** a count-prefixed skip requests more existing entries than are available in that direction,
* **When** it's resolved,
* **Then** it resolves to `nil` (mirroring today's uncounted "no entry in that direction" behavior), not the nearest entry short of N.

### **Busted Test Cases**

```
it("steps forward N days when count-prefixed", function()
    -- count = 3, target = "step_next"
    -- expect destination = current + 3 days
end)

it("steps backward N days when count-prefixed", function()
    -- symmetric case for "step_prev"
end)

it("skips forward to the Nth existing entry when count-prefixed", function()
    -- count = 2, target = "skip_next", multiple existing entries ahead
    -- expect the 2nd existing entry, not the 1st
end)

it("skips backward to the Nth existing entry when count-prefixed", function()
    -- symmetric case for "skip_prev"
end)

it("defaults to a single day/entry when no count is given", function()
    -- omit count (or pass nil) -- matches all existing, currently-passing specs
end)

it("resolves to nil when a count-prefixed skip requests more entries than exist", function()
end)

it("reads vim.v.count1 and passes it through when a default mapping is triggered", function()
    -- verify the keymap.set callback wiring threads v.count1 into execute()
end)

it("ignores a count prefix on the today/prompt/search mappings", function()
    -- gj / <leader>jj / <leader>fj with v.count1 > 1 set, verify no different behavior
end)
```
