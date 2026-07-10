## **Story: Consider count-prefixed navigation: stepwise vs. skip-search for past entries**

**Use Case:** None of `[j`/`]j`/`[J`/`]J` currently support a numeric count prefix (e.g. `3]j`) at all — pressing a count before them has no special effect today. If count-prefix support is added later, there's a design question specific to how it should interact with the existing step-vs-skip fork (see `skip-empty-days-past-sequential-future-navigation`, done): today-or-later navigation already steps exactly one calendar day at a time regardless of whether an entry exists for it; earlier navigation instead skips to the nearest *existing* entry. With a count prefix, should `3]j` from a historical date step back exactly 3 calendar days (mirroring today-or-later's stepping behavior), or skip back across 3 *existing* entries (extending the current skip-search behavior)? There's an argument for the former — stepping arguably ought to behave consistently regardless of direction or time period, and "skip to the Nth existing entry" is a meaningfully different, less predictable operation than "go back N days."

### **Acceptance Criteria**

Not yet defined — this is a design question to resolve when picked up, not a scoped feature yet. At minimum, decide:

* **Given** a count prefix on `[j`/`]j`/`[J`/`]J` navigating into the past,
* **When** resolving the destination,
* **Then** whether it steps back exactly N calendar days, or skips back across N existing entries — and whether the answer differs between `next`/`prev`, or between today-or-later vs. past — needs to be settled and written up as real Given/When/Then criteria before implementation.

### **Open questions — need deciding when this is picked up**

* Should count-prefix support extend to `gj`/`gJ`/`<leader>jj` at all, or only the step mappings?
* Does a count-prefixed step that starts in the past but crosses into today-or-later territory (e.g. `3]j` from two days before today) behave any differently than today's plain one-day step, or is it just "shift by N instead of 1" applied uniformly regardless of past/future?

### **Busted Test Cases**

Not yet applicable — no design has been settled to pin down with specs yet.
