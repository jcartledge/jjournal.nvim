## **Story: [tech] Make backlog search pluggable, defaulting to telescope with a vimgrep fallback**

**Use Case:** `search_backlog` hardcodes `require("telescope.builtin").live_grep`. If telescope isn't installed, triggering `<leader>fj` raises a raw "module not found" error instead of searching. Rather than just guarding against that, make the search backend configurable: default to telescope, fall back automatically to a builtin `:vimgrep`-based search when telescope isn't available, and let users override with `"telescope"`, `"builtin"`, or their own function for any other picker (fzf-lua, mini.pick, snacks.picker, etc.).

### **Acceptance Criteria**

* **Given** `config.search` is left at its default (`"auto"`) and telescope is installed,
* **When** the backlog search is triggered,
* **Then** it uses telescope's `live_grep`, scoped to the configured journal path, exactly as today.

* **Given** `config.search` is `"auto"` (the default) and telescope is not installed,
* **When** the backlog search is triggered,
* **Then** it silently falls back to the builtin search, with no error and no warning.

* **Given** `config.search` is explicitly set to `"telescope"` and telescope is not installed,
* **When** the backlog search is triggered,
* **Then** a `vim.notify` warning explains telescope is missing, and it still falls back to the builtin search.

* **Given** `config.search` is explicitly set to `"builtin"`,
* **When** the backlog search is triggered, regardless of whether telescope is installed,
* **Then** it uses the builtin search: prompt for a search term via `vim.ui.input`, run `:vimgrep` scoped to the configured path across `*.md` files, and open the quickfix list.

* **Given** `config.search` is set to a function,
* **When** the backlog search is triggered,
* **Then** that function is called directly with the configured journal path, and no builtin/telescope logic runs.

* **Given** `config.search` is set to an unrecognized string,
* **When** the backlog search is triggered,
* **Then** a `vim.notify` warning names the invalid value, and nothing else happens.

### **Busted Test Cases**

```
it("uses telescope by default when it is available", function()
    -- fake telescope.builtin.live_grep installed via package.loaded,
    -- config.search left at its default, call jjournal.search_backlog(),
    -- assert live_grep was called with the configured path, and no vim.notify warning fired
end)

it("falls back to the builtin search silently in 'auto' mode when telescope is unavailable", function()
    -- ensure package.loaded["telescope.builtin"] is nil / require fails,
    -- config.search left at its default, stub vim.ui.input and vim.cmd,
    -- call jjournal.search_backlog(), assert the builtin flow ran and vim.notify was not called
end)

it("warns and falls back to builtin when 'telescope' is explicitly requested but unavailable", function()
    -- config.search = "telescope", telescope unavailable, stub vim.notify/vim.ui.input/vim.cmd,
    -- call jjournal.search_backlog(), assert vim.notify WARN fired and the builtin flow ran
end)

it("uses the builtin search when 'builtin' is explicitly configured, even if telescope is available", function()
    -- config.search = "builtin", fake telescope.builtin installed but unused,
    -- stub vim.ui.input and vim.cmd, call jjournal.search_backlog(),
    -- assert the builtin flow ran and telescope's live_grep was never called
end)

it("prompts for a term and vimgreps the configured path when using the builtin search", function()
    -- config.search = "builtin", stub vim.ui.input to supply a term, stub vim.cmd,
    -- call jjournal.search_backlog(),
    -- assert vim.cmd was called with a vimgrep command scoped to the configured path and *.md,
    -- followed by opening the quickfix list
end)

it("does not vimgrep when the search prompt is cancelled", function()
    -- config.search = "builtin", stub vim.ui.input to cancel (nil/empty input), stub vim.cmd,
    -- call jjournal.search_backlog(), assert vim.cmd was never called
end)

it("calls a function configured as config.search directly with the journal path", function()
    -- config.search = a stub function,
    -- call jjournal.search_backlog(), assert the function was called once with config.path
end)

it("warns and does nothing for an unrecognized config.search value", function()
    -- config.search = "not-a-real-provider", stub vim.notify,
    -- call jjournal.search_backlog(), assert vim.notify WARN fired naming the bad value
end)
```
