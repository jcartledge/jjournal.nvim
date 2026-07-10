## **Story: Support count-prefixed step navigation ([j/]j/[J/]J)**

**Use Case:** No count-handling exists today: `vim.keymap.set`'s callback ignores `v:count` entirely, so pressing `3]j` behaves identically to a single `]j` — a natural, idiomatic Vim expectation (repeatable normal-mode motions) that's currently just missing. Implementing it for the unambiguous case — today-or-later, which already steps by a fixed 1 calendar day and generalizes cleanly to N — closes that gap.

What a count should mean when the shifted destination still lands *before* today is a separate, harder question: skip across N *existing* entries (extending today's single skip-search), or step back exactly N *calendar* days regardless of whether entries exist for each (mirroring the today-or-later behavior)? There's an argument for the latter — stepping arguably ought to behave consistently regardless of direction or time period, and "skip to the Nth existing entry" is a meaningfully different, less predictable operation than "go back N days." This is deliberately left unresolved for now (see "Open questions"); in the meantime, a count is simply ignored once the destination falls into that branch, exactly matching today's uncounted behavior — not silently guessing an answer to the open question.

### **Acceptance Criteria**

* **Given** `]j`/`[j`/`]J`/`[J` are pressed with a numeric count prefix (e.g. `3]j`),
* **When** the shifted destination (the current date shifted by the count, in that direction) is today or later,
* **Then** it steps exactly that many calendar days, landing directly on the destination (creating it if needed) — generalizing today's single-day step to N.

* **Given** no count prefix is given,
* **When** any of `]j`/`[j`/`]J`/`[J` are pressed,
* **Then** behavior is unchanged from today (a count of 1, matching Neovim's own `v:count1` default).

* **Given** a count prefix on `gj`/`gJ`/`<leader>jj`/`<leader>jJ`/`<leader>fj`,
* **When** any of those are pressed,
* **Then** the count is ignored — it has no defined meaning for "today", "prompt", or "search" targets.

* **Given** a count-prefixed step whose shifted destination is still before today,
* **When** it's resolved,
* **Then** the count is ignored and it falls back to today's single skip-to-nearest-existing-entry behavior, unchanged — the deliberately-unresolved case; see "Open questions".

* **Given** `M.execute`/`M.resolve_date` are called directly (e.g. by a user with `use_default_mappings = false` wiring their own mappings),
* **When** a count matters to them,
* **Then** both accept it as a new optional trailing parameter (defaulting to 1 when omitted) — mirroring `vim.v.count1`, which is what the default mapping wrapper reads and passes through — so this isn't only reachable via the built-in mappings.

### **Open questions — need deciding when this is picked up (or as a fast follow-up)**

* Should a count-prefixed step landing before today skip across N *existing* entries, or step back exactly N *calendar* days regardless of whether entries exist for each? Not yet decided — see the Use Case above for the argument either way.

### **Busted Test Cases**

```
it("steps forward N days directly when the count-shifted destination is today or later", function()
    -- count = 3, target = "next", current anchored 2 days before today
    -- expect destination = current + 3 days (still >= today)
end)

it("steps backward N days directly when the count-shifted destination is today or later", function()
    -- symmetric case for "prev"
end)

it("defaults to a single day when no count is given", function()
    -- omit count (or pass nil) -- matches all existing, currently-passing specs
end)

it("ignores the count when the count-shifted destination is still before today", function()
    -- count = 3, current - 3 days still < today
    -- expect the same result as today's existing single skip-to-nearest-entry behavior
end)

it("reads vim.v.count1 and passes it through when a default mapping is triggered", function()
    -- verify the keymap.set callback wiring threads v.count1 into execute()
end)

it("ignores a count prefix on the today/prompt/search mappings", function()
    -- gj / <leader>jj / <leader>fj with v.count1 > 1 set, verify no different behavior
end)
```
