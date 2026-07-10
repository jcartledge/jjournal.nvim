## **Story: Step day-by-day into today/future, skip to existing entries in the past**

**Use Case:** When browsing history (`[j`/`]j` on dates before today), you want to skip empty days so you can move between what you've actually written without clicking through blank ones. When navigating on or into the future, you want to step exactly one calendar day at a time and land there directly — whether or not a file exists yet — so you can walk from today into tomorrow, the day after, etc. to plan ahead.

The fork is decided by the **destination**, not which key you pressed or where you currently are: shift the current date by one day in the requested direction; if that shifted date is today or later, go there directly (creating it on open if needed); otherwise, fall back to the existing skip-to-nearest-existing-entry search, unchanged.

Worked examples:
* On today, `]j` → tomorrow is today-or-later → step to tomorrow directly, even with nothing written yet.
* On tomorrow, `[j` → today is today-or-later → step to today directly.
* On yesterday, `]j` → today is today-or-later → step straight to today, *not* a skip-search forward through existing entries.
* Deep in history, `]j` or `[j` where the one-day shift is still before today → unchanged skip-to-nearest-existing-entry behavior.

### **Acceptance Criteria**

* **Given** the current date shifted by one day in the requested direction is today or later,
* **When** `next`/`prev` navigation runs,
* **Then** that shifted date is returned directly (and, via the existing `open_date` auto-creation, opened whether or not a file exists for it).

* **Given** the current date shifted by one day in the requested direction is still before today,
* **When** `next`/`prev` navigation runs,
* **Then** it falls back to the existing skip-to-nearest-existing-entry search (unchanged from current behavior).

* **Given** navigating `next` from yesterday (where the one-day shift lands exactly on today),
* **When** this happens,
* **Then** it steps directly to today rather than skip-searching for existing entries.

* **Given** a one-day shift crosses a month or year boundary,
* **When** navigation runs,
* **Then** the shift is computed correctly (e.g. Dec 31 -> Jan 1).

### **Consequences for existing tests**

Two existing `jjournal.resolve_date` tests currently assert that `next` returns `nil` when the buffer is outside the journal path (so `current` falls back to today) and no file exists beyond it. Under the new rule, falling back to today means `next` now steps directly to tomorrow instead of skip-searching — so both need their assertion changed from "resolves to nil" to "resolves to tomorrow's date", not because the outside-path fallback itself is wrong, but because "next from today" now behaves differently.

The existing skip-search tests (`"resolves 'next' by stepping forward across empty days..."`, `"resolves 'prev' by stepping backward..."`, `"resolves 'next' to nil when there is no later entry"`) don't currently mock `vim.fn.strftime`, so "today" in them is whatever the real wall-clock date is when the suite runs — harmless today since their fixture dates (2026-06-*) are safely in the past, but implicit. Since "is the shifted date >= today" is now load-bearing, these get an explicit `fn.strftime` mock so they're deterministic regardless of when the suite actually runs.

### **Busted Test Cases**

```
it("steps forward to tomorrow directly when today or later, even with no file for it yet", function()
    -- current = today (via buffer name / expand), fn.strftime = today
    -- resolve_date("next", ...) resolves to today + 1, no glob/discovery involved
end)

it("steps backward to today directly when navigating prev from tomorrow", function()
    -- current = tomorrow, fn.strftime = today
    -- resolve_date("prev", ...) resolves to today
end)

it("steps directly to today when next from yesterday would land on today, without skip-searching", function()
    -- current = yesterday, fn.strftime = today
    -- resolve_date("next", ...) resolves to today directly (not a skip-search result)
end)

it("shifts correctly across a year boundary", function()
    -- current = 2025-12-31, fn.strftime = 2026-01-01
    -- resolve_date("next", ...) resolves to 2026-01-01
end)

it("falls back to skip-search when the shifted date is still before today", function()
    -- unchanged behavior, now with fn.strftime explicitly mocked well after the fixture dates
end)
```

## **Story: Replace today-relative step/skip with two explicit navigation modes**

**Use Case:** The fork above is decided by *destination relative to today*, which is exactly why it took real effort to trust it was behaving correctly in practice ("the UX might take a little getting used to... I had to convince myself it was working correctly"): the same keypress does one of two different things depending on where you currently are, with no visible signal which one just happened. Splitting this into two explicit, orthogonal, always-consistent primitives removes that ambiguity entirely: **step** always shifts by exactly one day (or N with a count — see `support-count-prefix-step-navigation.md`), creating the entry as needed, in either direction, regardless of today. **Skip** always jumps to the nearest existing entry (or Nth with a count), in either direction, regardless of today. Today stops being special-cased in the navigation logic at all.

New default mappings (replacing `[j`/`]j`/`[J`/`]J` now that split variants are gone entirely — see `split-window-navigation-mappings.md`):

* `[jj` / `]jj` — step: shift exactly one day back/forward, creating the entry if needed, regardless of past or future.
* `[j` / `]j` — skip: jump to the nearest existing entry back/forward, regardless of past or future.

This is a deliberate pre-release breaking change to both the default mappings and to `dates.get_nav_date`'s behavior — no more today-relative branching anywhere in the navigation logic.

### **Acceptance Criteria**

* **Given** `]jj`/`[jj` (step),
* **When** triggered from any date, past or future,
* **Then** it shifts exactly one calendar day in that direction and opens it, creating the entry if it doesn't exist — never skip-searching, regardless of whether the result lands before or after today.

* **Given** `]j`/`[j` (skip),
* **When** triggered from any date, past or future,
* **Then** it jumps to the nearest existing entry (on disk or in an open buffer) in that direction — never stepping into a blank day, regardless of whether the result lands before or after today.

* **Given** `dates.lua`,
* **When** this lands,
* **Then** `get_nav_date`'s today-relative branch is removed entirely, replaced with two separate, simpler functions with no dependency on "today" at all (naming TBD, see "Open questions").

* **Given** the worked examples and today-relative language in this file's original section above,
* **When** this lands,
* **Then** that section is superseded, not deleted — it stays as the historical record of what was built first; this section documents the replacement.

### **Open questions — need deciding when this is picked up**

* Naming for the two new `dates.lua` functions — `step`/`skip`, matching the mapping vocabulary already agreed on, or something else?

### **Busted Test Cases**

```
it("steps back or forward exactly one day regardless of whether the result lands before today", function()
end)

it("skips to the nearest existing entry regardless of whether the result lands before today", function()
end)

it("skip resolves to nil when there is no existing entry in that direction", function()
    -- matches today's existing "no later entry" behavior, now unconditional
end)
```

All specs currently in this file's original "Busted Test Cases" section (the today-relative step/skip fork) get replaced outright, not adapted, since the fork they test no longer exists — kept above as historical record of what shipped first.

Once this lands, `support-count-prefix-step-navigation.md` will need its own naming/reference update: it currently refers to `[j`/`]j`/`[J`/`]J` and the today-relative branching, both of which this story removes. Its core acceptance criteria (count generalizes step to N days, ignored for today/prompt/search) still hold, and the "open question" about past-direction ambiguity is resolved rather than left open — a count now unambiguously means N for either mode.
