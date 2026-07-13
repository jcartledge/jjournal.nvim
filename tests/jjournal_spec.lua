local jjournal = require("jjournal")
local assert = require("luassert")
local setup_test = require("support.setup_test")
local busted = require("busted")
local describe, it = busted.describe, busted.it

describe("jjournal config", function()
	it("defaults to '~/notes/journals/' with default mappings enabled before setup() is called", function()
		package.loaded["jjournal"] = nil
		local fresh = require("jjournal")
		package.loaded["jjournal"] = jjournal -- restore the shared instance used by the rest of the suite

		assert.are.equal(vim.fn.expand("~/notes/journals/"), fresh.config.base_dir)
		assert.is_true(fresh.config.use_default_mappings)
	end)

	it("defaults file_path to nested year/month directories", function()
		package.loaded["jjournal"] = nil
		local fresh = require("jjournal")
		package.loaded["jjournal"] = jjournal

		assert.are.equal("%Y/%m/%Y-%m-%d.md", fresh.config.file_path)
	end)

	it("normalizes a configured path that has no trailing slash", function()
		setup_test({
			config = { base_dir = "/virtual/test/no-trailing-slash" },
			vim = { cmd = true },
		}, function()
			jjournal.open_date("2026-07-09", "edit")

			assert.stub(vim.cmd).was_called_with("edit /virtual/test/no-trailing-slash/2026-07-09.md")
		end)
	end)
end)

describe("jjournal.resolve_date", function()
	-- Chronological step/skip specs anchor off the current buffer's
	-- jjournal_date -- the buffer-local var register_autocmds' tagging
	-- autocmd sets on every buffer it manages (see current_anchor_date in
	-- dates.lua). anchor_date sets that directly on a scratch buffer
	-- switched into as the current buffer for the test's duration; pass nil
	-- to exercise the fallback-to-today path (a buffer jjournal never
	-- tagged, e.g. one outside the configured journal path).
	local function setup_resolve_date_test(anchor_date, overrides, test_fn)
		setup_test(overrides or {}, function()
			local buf = vim.api.nvim_create_buf(false, true)
			local original_buf = vim.api.nvim_get_current_buf()
			vim.api.nvim_set_current_buf(buf)
			if anchor_date then vim.b[buf].jjournal_date = anchor_date end

			local ok, err = pcall(test_fn)

			vim.api.nvim_set_current_buf(original_buf)
			vim.api.nvim_buf_delete(buf, { force = true })
			if not ok then error(err, 0) end
		end)
	end

	it("resolves 'today' to today's date", function()
		setup_test(nil, function()
			local expected_today = vim.fn.strftime("%F")

			jjournal.resolve_date("today", function(resolved_date)
				assert.are.equal(expected_today, resolved_date)
			end)
		end)
	end)

	it("resolves 'skip_next' by skipping across empty days to the next existing entry", function()
		setup_resolve_date_test("2026-06-01", {
			fn = { glob = { "2026-06-01.md", "2026-06-03.md" } },
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-06-03", resolved_date)
			end)
		end)
	end)

	it("prioritizes virtual unwritten buffers over disk storage when resolving 'skip_next'", function()
		setup_resolve_date_test("2026-06-01", {
			fn = { glob = { "2026-06-01.md", "2026-06-03.md" } },
			api = {
				nvim_list_bufs = { 101, 102 },
				nvim_buf_is_loaded = true,
				nvim_buf_get_name = "/virtual/test/journal/path/2026-06-02.md",
			},
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-06-02", resolved_date)
			end)
		end)
	end)

	it("resolves 'skip_next' to nil when there is no later entry", function()
		setup_resolve_date_test("2026-06-02", {
			fn = { glob = { "2026-06-01.md", "2026-06-02.md" } },
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.is_nil(resolved_date)
			end)
		end)
	end)

	it("resolves 'skip_prev' by skipping across empty days to the previous existing entry", function()
		setup_resolve_date_test("2026-06-03", {
			fn = { glob = { "2026-06-01.md", "2026-06-03.md" } },
		}, function()
			jjournal.resolve_date("skip_prev", function(resolved_date)
				assert.are.equal("2026-06-01", resolved_date)
			end)
		end)
	end)

	-- Unlike the old today-relative hybrid, skip behaves the same whether
	-- the result lands before or after today -- this specific case (an
	-- existing entry days after today) previously would have been
	-- unreachable, since anything after today always stepped instead.
	it("skips forward to an existing entry even when it lands after today", function()
		setup_resolve_date_test("2026-07-10", {
			fn = { glob = { "2026-07-10.md", "2026-07-15.md" } },
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-07-15", resolved_date)
			end)
		end)
	end)

	-- The default step/skip mappings are buffer_local (see
	-- bind_buffer_local_mappings), so pressing one of them from outside a
	-- journal buffer is no longer possible -- this exercises resolve_date's
	-- own defensive fallback directly instead, which still matters for
	-- anyone calling execute()/resolve_date() themselves (e.g. a custom
	-- global mapping with use_default_mappings = false).
	it("falls back to today when the current buffer has no jjournal_date (e.g. outside the journal path, or never tagged)", function()
		setup_resolve_date_test(nil, {
			fn = { strftime = "2026-07-10" },
		}, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-07-11", resolved_date)
			end)
		end)
	end)

	it("discovers nested, non-.md journal files by extracting the date from an arbitrary filename", function()
		setup_resolve_date_test("2026-06-01", {
			fn = {
				glob = {
					"/virtual/test/journal/path/2026/06/journal-2026-06-01.txt",
					"/virtual/test/journal/path/2026/06/journal-2026-06-03.txt",
				},
			},
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-06-03", resolved_date)
			end)
		end)
	end)

	it("steps forward exactly one day, creating the entry even if it doesn't exist yet", function()
		setup_resolve_date_test("2026-07-10", nil, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-07-11", resolved_date)
			end)
		end)
	end)

	it("steps backward exactly one day", function()
		setup_resolve_date_test("2026-07-11", nil, function()
			jjournal.resolve_date("step_prev", function(resolved_date)
				assert.are.equal("2026-07-10", resolved_date)
			end)
		end)
	end)

	-- Unlike the old today-relative hybrid, step behaves the same whether
	-- the result lands before or after today -- this previously would have
	-- fallen back to skip-searching instead.
	it("steps forward exactly one day even when the result lands before today", function()
		setup_resolve_date_test("2026-06-01", nil, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-06-02", resolved_date)
			end)
		end)
	end)

	it("shifts correctly across a year boundary", function()
		setup_resolve_date_test("2025-12-31", nil, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-01-01", resolved_date)
			end)
		end)
	end)

	it("steps forward N days when count-prefixed", function()
		setup_resolve_date_test("2026-07-10", nil, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-07-13", resolved_date)
			end, 3)
		end)
	end)

	it("steps backward N days when count-prefixed", function()
		setup_resolve_date_test("2026-07-13", nil, function()
			jjournal.resolve_date("step_prev", function(resolved_date)
				assert.are.equal("2026-07-10", resolved_date)
			end, 3)
		end)
	end)

	it("skips forward to the Nth existing entry when count-prefixed", function()
		setup_resolve_date_test("2026-06-01", {
			fn = { glob = { "2026-06-01.md", "2026-06-03.md", "2026-06-05.md" } },
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-06-05", resolved_date)
			end, 2)
		end)
	end)

	it("skips backward to the Nth existing entry when count-prefixed", function()
		setup_resolve_date_test("2026-06-05", {
			fn = { glob = { "2026-06-01.md", "2026-06-03.md", "2026-06-05.md" } },
		}, function()
			jjournal.resolve_date("skip_prev", function(resolved_date)
				assert.are.equal("2026-06-01", resolved_date)
			end, 2)
		end)
	end)

	it("resolves to nil when a count-prefixed skip requests more entries than exist", function()
		setup_resolve_date_test("2026-06-01", {
			fn = { glob = { "2026-06-01.md", "2026-06-03.md" } },
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.is_nil(resolved_date)
			end, 5)
		end)
	end)

	it("resolves 'prompt' by delegating to prompt_for_date", function()
		setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
		}, function()
			local received
			jjournal.resolve_date("prompt", function(date)
				received = date
			end)

			assert.are.equal("2026-07-09", received)
		end)
	end)
end)

describe("jjournal.resolve_path", function()
	it("resolves the default template the same as the previous flat layout", function()
		setup_test(nil, function()
			assert.are.equal("/virtual/test/journal/path/2026-07-09.md", jjournal.resolve_path("2026-07-09"))
		end)
	end)

	it("resolves %Y/%m/%d placeholders against a nested template", function()
		setup_test({ config = { file_path = "%Y/%m/%Y-%m-%d.md" } }, function()
			assert.are.equal("/virtual/test/journal/path/2026/07/2026-07-09.md", jjournal.resolve_path("2026-07-09"))
		end)
	end)

	it("resolves %D as shorthand for the full date alongside individual %Y/%m/%d tokens", function()
		setup_test({ config = { file_path = "%Y/%m/%d/journal-%D.txt" } }, function()
			assert.are.equal(
				"/virtual/test/journal/path/2026/07/09/journal-2026-07-09.txt",
				jjournal.resolve_path("2026-07-09")
			)
		end)
	end)
end)

describe("jjournal.prompt_for_date", function()
	it("invokes the callback with user input", function()
		setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
		}, function()
			local received
			jjournal.prompt_for_date(function(date)
				received = date
			end)

			assert.are.equal("2026-07-09", received)
		end)
	end)

	it("does not invoke the callback when the prompt is cancelled", function()
		setup_test({
			ui = { input = function(_, callback) callback(nil) end },
		}, function()
			local was_called = false
			jjournal.prompt_for_date(function()
				was_called = true
			end)

			assert.is_false(was_called)
		end)
	end)
end)

describe("jjournal.open_date", function()
	local function setup_open_date_test(overrides, test_fn)
		setup_test(vim.tbl_deep_extend("force", {
			vim = { cmd = true },
		}, overrides or {}), test_fn)
	end

	it("opens the resolved date with the given command", function()
		setup_open_date_test(nil, function()
			jjournal.open_date("2026-07-09", "vsplit")

			assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-09.md")
		end)
	end)

	it("defaults to 'edit' when no command is given", function()
		setup_open_date_test(nil, function()
			jjournal.open_date("2026-07-09")

			assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026-07-09.md")
		end)
	end)

	it("opens the file at the path resolved from a custom nested path_template", function()
		setup_open_date_test({ config = { file_path = "%Y/%m/%Y-%m-%d.md" } }, function()
			jjournal.open_date("2026-07-09", "edit")

			assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026/07/2026-07-09.md")
		end)
	end)

	it("warns and does not open anything when date_str is nil", function()
		setup_open_date_test({ vim = { notify = true } }, function()
			jjournal.open_date(nil)

			assert.stub(vim.notify).was_called(1)
			assert.are.equal(vim.log.levels.WARN, vim.notify.calls[1].vals[2])
			assert.stub(vim.cmd).was_not_called()
		end)
	end)

	-- Directory creation is deliberately NOT open_date's job -- see the
	-- "just-in-time directory creation" describe block below. Opening a
	-- buffer for a path whose parent directory doesn't exist yet is valid
	-- Neovim behavior on its own (verified against real Vim: :edit succeeds
	-- regardless, only :write needs the directory to exist) -- so
	-- open_date creating it eagerly would risk leaving an empty, orphaned
	-- directory behind for a buffer that's opened and later discarded
	-- unsaved (e.g. an auto-wiped, never-edited preview).
	it("does not create any directory when opening a buffer", function()
		setup_open_date_test({ fn = { mkdir = true } }, function()
			jjournal.open_date("2026-07-09", "edit")

			assert.stub(vim.fn.mkdir).was_not_called()
		end)
	end)
end)

describe("jjournal.search_backlog", function()
	it("uses telescope by default when it is available", function()
		local fake_builtin = { live_grep = function() end }
		package.loaded["telescope.builtin"] = fake_builtin

		local ok, err = pcall(function()
			setup_test({
				on = { { fake_builtin, "live_grep" } },
				vim = { notify = true },
			}, function()
				jjournal.search_backlog()

				assert.stub(fake_builtin.live_grep).was_called(1)
				local call_args = fake_builtin.live_grep.calls[1].vals[1]
				assert.are.same({ "/virtual/test/journal/path/" }, call_args.search_dirs)
				assert.are.equal("Search Journal Backlog", call_args.prompt_title)
				assert.stub(vim.notify).was_not_called()
			end)
		end)

		package.loaded["telescope.builtin"] = nil
		if not ok then error(err, 0) end
	end)

	it("falls back to the builtin search silently in 'auto' mode when telescope is unavailable", function()
		setup_test({
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true, notify = true },
		}, function()
			jjournal.search_backlog()

			assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.md")
			assert.stub(vim.cmd).was_called_with("copen")
			assert.stub(vim.notify).was_not_called()
		end)
	end)

	it("warns and falls back to builtin when 'telescope' is explicitly requested but unavailable", function()
		setup_test({
			config = { search = "telescope" },
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true, notify = true },
		}, function()
			jjournal.search_backlog()

			assert.stub(vim.notify).was_called(1)
			assert.are.equal(vim.log.levels.WARN, vim.notify.calls[1].vals[2])
			assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.md")
		end)
	end)

	it("uses the builtin search when 'builtin' is explicitly configured, even if telescope is available", function()
		local fake_builtin = { live_grep = function() end }
		package.loaded["telescope.builtin"] = fake_builtin

		local ok, err = pcall(function()
			setup_test({
				config = { search = "builtin" },
				on = { { fake_builtin, "live_grep" } },
				ui = { input = function(_, callback) callback("todo") end },
				vim = { cmd = true },
			}, function()
				jjournal.search_backlog()

				assert.stub(fake_builtin.live_grep).was_not_called()
				assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.md")
			end)
		end)

		package.loaded["telescope.builtin"] = nil
		if not ok then error(err, 0) end
	end)

	it("scopes the builtin vimgrep recursively to the extension configured via path_template", function()
		setup_test({
			config = { search = "builtin", file_path = "%Y/%m/%d/journal-%D.txt" },
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true },
		}, function()
			jjournal.search_backlog()

			assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.txt")
		end)
	end)

	it("escapes slashes in the search term before building the vimgrep pattern", function()
		setup_test({
			config = { search = "builtin" },
			ui = { input = function(_, callback) callback("a/b") end },
			vim = { cmd = true },
		}, function()
			jjournal.search_backlog()

			assert.stub(vim.cmd).was_called_with("vimgrep /a\\/b/gj /virtual/test/journal/path/**/*.md")
			assert.stub(vim.cmd).was_called_with("copen")
		end)
	end)

	it("does not vimgrep when the search prompt is cancelled", function()
		setup_test({
			config = { search = "builtin" },
			ui = { input = function(_, callback) callback(nil) end },
			vim = { cmd = true },
		}, function()
			jjournal.search_backlog()

			assert.stub(vim.cmd).was_not_called()
		end)
	end)

	it("calls a function configured as config.search directly with the journal path", function()
		local received_path
		setup_test({
			config = {
				search = function(path)
					received_path = path
				end,
			},
		}, function()
			jjournal.search_backlog()

			assert.are.equal("/virtual/test/journal/path/", received_path)
		end)
	end)

	it("warns and does nothing for an unrecognized config.search value", function()
		setup_test({
			config = { search = "not-a-real-provider" },
			vim = { notify = true, cmd = true },
		}, function()
			jjournal.search_backlog()

			assert.stub(vim.notify).was_called(1)
			assert.are.equal(vim.log.levels.WARN, vim.notify.calls[1].vals[2])
			assert.stub(vim.cmd).was_not_called()
		end)
	end)
end)

describe("jjournal.execute", function()
	it("runs the search provider for the 'search' target without resolving or opening a date", function()
		setup_test({
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true },
		}, function()
			jjournal.execute("search")

			assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.md")
		end)
	end)

	it("resolves and opens a date for non-search targets", function()
		setup_test({
			fn = { strftime = "2026-07-10" },
			vim = { cmd = true },
		}, function()
			jjournal.execute("today", "vsplit")

			assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-10.md")
		end)
	end)

	it("prompts for a date and opens it in a vsplit for the 'prompt' target", function()
		setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
			vim = { cmd = true },
		}, function()
			jjournal.execute("prompt", "vsplit")

			assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-09.md")
		end)
	end)

	it("pins the current buffer for the 'pin' target without resolving or opening a date", function()
		setup_test(nil, function()
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_current_buf(buf)

			jjournal.execute("pin")

			assert.is_true(vim.b[buf].jjournal_pinned)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	it("ignores a count prefix for the 'today' target", function()
		setup_test({
			fn = { strftime = "2026-07-10" },
			vim = { cmd = true },
		}, function()
			jjournal.execute("today", "edit", 5)

			assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026-07-10.md")
		end)
	end)

	it("ignores a count prefix for the 'prompt' target", function()
		setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
			vim = { cmd = true },
		}, function()
			jjournal.execute("prompt", "edit", 5)

			assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026-07-09.md")
		end)
	end)

	it("ignores a count prefix for the 'search' target", function()
		setup_test({
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true },
		}, function()
			jjournal.execute("search", nil, 5)

			assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.md")
		end)
	end)

	it("ignores a count prefix for the 'pin' target", function()
		setup_test(nil, function()
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_current_buf(buf)

			jjournal.execute("pin", nil, 5)

			assert.is_true(vim.b[buf].jjournal_pinned)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)

describe("jjournal.pin_buffer", function()
	it("marks the current buffer as pinned", function()
		setup_test(nil, function()
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_current_buf(buf)

			jjournal.pin_buffer()

			assert.is_true(vim.b[buf].jjournal_pinned)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	it("redraws the statusline so a pin indicator shows immediately, not on the next unrelated redraw", function()
		setup_test({ vim = { cmd = true } }, function()
			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_set_current_buf(buf)

			jjournal.pin_buffer()

			assert.stub(vim.cmd).was_called_with("redrawstatus")

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)

describe("jjournal.setup", function()
	-- Every spec here needs vim.keymap.set stubbed; override config to flip
	-- use_default_mappings on, or add other mocks, per test.
	local function setup_setup_test(overrides, test_fn)
		setup_test(vim.tbl_deep_extend("force", {
			keymap = { set = true },
		}, overrides or {}), test_fn)
	end

	-- register_autocmds registers three autocmds now (status-tagging,
	-- pin-on-edit, and cleanup), so capturing "the" callback needs to say
	-- which event it means -- matched via vim.deep_equal since the status
	-- and pin-on-edit autocmds each register a list of events and the
	-- cleanup one registers a bare string. Shared by the "journal buffer
	-- status autocmd" and "buffer cleanup and pinning autocmds" blocks below.
	local function capture_autocmd_callback(events, overrides)
		local captured
		setup_test(vim.tbl_deep_extend("force", {
			api = {
				nvim_create_autocmd = function(evts, opts)
					if vim.deep_equal(evts, events) then captured = opts.callback end
				end,
			},
		}, overrides or {}), function() end)
		return captured
	end

	it("merges provided options over the existing config without clobbering unspecified keys", function()
		setup_setup_test(nil, function()
			jjournal.setup({ use_default_mappings = true })

			assert.are.equal("/virtual/test/journal/path/", jjournal.config.base_dir)
			assert.is_true(jjournal.config.use_default_mappings)
		end)
	end)

	it("binds every non-buffer_local default mapping in normal mode, wired to execute the right target/cmd/count, with its desc", function()
		setup_setup_test({
			config = { use_default_mappings = true },
			jjournal = { execute = true },
		}, function()
			local expected_count = 0
			for _, spec in pairs(jjournal.mappings) do
				if spec ~= false and not spec.buffer_local then expected_count = expected_count + 1 end
			end
			assert.stub(vim.keymap.set).was_called(expected_count)

			for lhs, spec in pairs(jjournal.mappings) do
				if spec ~= false and not spec.buffer_local then
					local matched
					for _, call in ipairs(vim.keymap.set.calls) do
						if call.vals[1] == "n" and call.vals[2] == lhs then
							matched = call
							break
						end
					end

					assert.is_not_nil(matched, "expected a keymap.set call for " .. lhs)
					assert.are.same({ desc = spec.desc, silent = true }, matched.vals[4])

					matched.vals[3]() -- invoke the bound handler as if the key had been pressed
					assert.stub(jjournal.execute).was_called_with(spec.target, spec.cmd, vim.v.count1)
				end
			end
		end)
	end)

	it("does not bind any buffer_local mapping globally", function()
		setup_setup_test({ config = { use_default_mappings = true } }, function()
			for lhs, spec in pairs(jjournal.mappings) do
				if spec ~= false and spec.buffer_local then
					for _, call in ipairs(vim.keymap.set.calls) do
						assert.are_not.equal(lhs, call.vals[2])
					end
				end
			end
		end)
	end)

	it("skips keymap binding entirely when use_default_mappings is false", function()
		setup_setup_test(nil, function()
			assert.stub(vim.keymap.set).was_not_called()
		end)
	end)

	it("skips binding an individual mapping that has been explicitly disabled with false", function()
		local original_spec = jjournal.mappings["gj"]
		jjournal.mappings["gj"] = false

		local ok, err = pcall(function()
			setup_setup_test({ config = { use_default_mappings = true } }, function()
				for _, call in ipairs(vim.keymap.set.calls) do
					assert.are_not.equal("gj", call.vals[2])
				end
			end)
		end)

		jjournal.mappings["gj"] = original_spec
		if not ok then error(err, 0) end
	end)

	describe("file_path validation", function()
		it("errors when the filename portion has no way to recover the full date", function()
			assert.has_error(function()
				setup_test({ config = { file_path = "%Y/%m/%d.md" } }, function() end)
			end)
		end)

		it("accepts a filename containing the literal %Y-%m-%d with an arbitrary prefix/suffix and extension", function()
			setup_test({ config = { file_path = "%Y/%m/notes-%Y-%m-%d-final.txt" } }, function() end)
		end)

		it("accepts a filename containing %D as shorthand for the full date", function()
			setup_test({ config = { file_path = "%Y/%m/%d/journal-%D.txt" } }, function() end)
		end)
	end)

	describe("base_dir validation", function()
		-- Fakes Vim's own fnamemodify(":h"/":p") for exercising the upward
		-- directory walk (nearest_existing_ancestor in path.lua) without
		-- touching the real filesystem. Shared across every spec below since
		-- it's a fixed, reusable path-splitting stand-in -- what varies per
		-- spec is which specific paths isdirectory/filewritable report as
		-- existing/writable, not this.
		local function fake_fnamemodify(path_str, mods)
			if mods == ":p" then return path_str end
			if mods == ":h" then
				-- A top-level directory's (e.g. "/virtual") parent is "/" itself,
				-- not "" -- real fnamemodify(":h") agrees, so this has to match
				-- for the "reaches the filesystem root" spec below to be
				-- reachable at all via the walk, the same way it would for real.
				local parent = path_str:match("^(.*)/[^/]+$")
				return (not parent or parent == "") and "/" or parent
			end
			return path_str
		end

		-- The default base_dir ("/virtual/test/journal/path/") doesn't exist
		-- on the real filesystem the test suite runs on, so real
		-- isdirectory/filewritable calls against it already return 0/false
		-- without needing to be mocked -- only filereadable needs faking here,
		-- to simulate "this path exists, but as a file".
		it("errors and does not proceed when base_dir already exists as a file, not a directory", function()
			assert.has_error(function()
				setup_test({ fn = { filereadable = 1 } }, function() end)
			end)
		end)

		it("does not warn when base_dir already exists and is a writable directory", function()
			setup_test({
				fn = { isdirectory = 1, filewritable = 2 },
				vim = { notify = true },
			}, function()
				assert.stub(vim.notify).was_not_called()
			end)
		end)

		it("does not warn when base_dir doesn't exist yet but its writable parent does", function()
			setup_test({
				fn = {
					isdirectory = function(dir) return dir == "/virtual/test/journal" and 1 or 0 end,
					fnamemodify = fake_fnamemodify,
					filewritable = function(dir) return dir == "/virtual/test/journal" and 2 or 0 end,
				},
				vim = { notify = true },
			}, function()
				assert.stub(vim.notify).was_not_called()
			end)
		end)

		it("walks up multiple missing levels to find the nearest existing ancestor", function()
			setup_test({
				fn = {
					isdirectory = function(dir) return dir == "/virtual/test" and 1 or 0 end,
					fnamemodify = fake_fnamemodify,
					filewritable = function(dir) return dir == "/virtual/test" and 2 or 0 end,
				},
				vim = { notify = true },
			}, function()
				assert.stub(vim.notify).was_not_called()
			end)
		end)

		-- Doesn't rely on the real filesystem happening to lack a "/virtual"
		-- directory (which is what makes every OTHER spec in this suite's
		-- default fixture harmless, since their walk also reaches here) --
		-- mocked explicitly so this behavior is pinned down deliberately
		-- rather than working by accident of the fixture path chosen.
		it("does not warn when the walk reaches the filesystem root with no other existing ancestor found", function()
			setup_test({
				fn = {
					isdirectory = function(dir) return dir == "/" and 1 or 0 end,
					fnamemodify = fake_fnamemodify,
					filewritable = 0,
				},
				vim = { notify = true },
			}, function()
				assert.stub(vim.notify).was_not_called()
			end)
		end)

		it("warns but still binds mappings/autocmds when the nearest existing ancestor isn't writable", function()
			setup_test({
				fn = {
					isdirectory = function(dir) return dir == "/virtual/test/journal" and 1 or 0 end,
					fnamemodify = fake_fnamemodify,
					filewritable = 0,
				},
				config = { use_default_mappings = true },
				keymap = { set = true },
				vim = { notify = true },
			}, function()
				assert.stub(vim.notify).was_called(1)
				assert.are.equal(vim.log.levels.ERROR, vim.notify.calls[1].vals[2])
				assert.matches("base_dir", vim.notify.calls[1].vals[1])
				assert.stub(vim.keymap.set).was_called()
			end)
		end)
	end)

	describe("journal buffer status autocmd", function()
		it("registers a BufReadPost/BufNewFile autocmd scoped recursively to the configured journal path", function()
			setup_test({ api = { nvim_create_autocmd = true } }, function()
				-- Called four times total: this autocmd plus the pin-on-edit,
				-- BufWinLeave cleanup, and just-in-time mkdir autocmds registered
				-- alongside it (see the "buffer cleanup and pinning autocmds" and
				-- "just-in-time directory creation" describe blocks below) -- all
				-- four sharing the same augroup and pattern, registered in this
				-- order.
				assert.stub(vim.api.nvim_create_autocmd).was_called(4)
				local events = vim.api.nvim_create_autocmd.calls[1].vals[1]
				local opts = vim.api.nvim_create_autocmd.calls[1].vals[2]
				assert.are.same({ "BufReadPost", "BufNewFile" }, events)
				assert.are.equal("/virtual/test/journal/path/**.md", opts.pattern)
			end)
		end)

		it("scopes the autocmd pattern recursively to the extension configured via file_path", function()
			setup_test({
				api = { nvim_create_autocmd = true },
				config = { file_path = "%Y/%m/%d/journal-%D.txt" },
			}, function()
				local opts = vim.api.nvim_create_autocmd.calls[1].vals[2]
				assert.are.equal("/virtual/test/journal/path/**.txt", opts.pattern)
			end)
		end)

		local function setup_status_test(buffer_name, test_fn)
			setup_test({ api = { nvim_buf_get_name = buffer_name } }, test_fn)
		end

		it("tags an opened journal buffer with jjournal_entry = true", function()
			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			setup_status_test("/virtual/test/journal/path/2026-07-10.md", function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				assert.is_true(vim.b[buf].jjournal_entry)

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("tags an opened journal buffer with jjournal_date extracted from its filename", function()
			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			setup_status_test("/virtual/test/journal/path/2026-06-01.md", function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				assert.are.equal("2026-06-01", vim.b[buf].jjournal_date)

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("extracts jjournal_date correctly for a custom nested file_path", function()
			local nested_template = "%Y/%m/%Y-%m-%d.md"
			local callback =
				capture_autocmd_callback({ "BufReadPost", "BufNewFile" }, { config = { file_path = nested_template } })
			setup_test({
				config = { file_path = nested_template },
				api = { nvim_buf_get_name = "/virtual/test/journal/path/2026/07/2026-07-10.md" },
			}, function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				assert.are.equal("2026-07-10", vim.b[buf].jjournal_date)

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		-- These two deviate deliberately from the mock-only convention used
		-- everywhere else in this file: every other spec here mocks
		-- nvim_create_autocmd and invokes the captured callback manually,
		-- which never exercises Neovim's own autocmd-pattern matching.
		-- register_autocmds previously built that pattern as "**/*" .. ext,
		-- which Neovim's real pattern matching requires at least one
		-- subdirectory between base_dir and the filename to satisfy -- so it
		-- silently never matched a flat (non-nested) file_path layout like
		-- the one these tests use. Only real files, a real (unmocked)
		-- nvim_create_autocmd, and a real :edit can catch that; a mocked
		-- callback invocation would pass either way.
		it("tags a real buffer for a flat (non-nested) file_path layout via a real, unmocked autocmd", function()
			local tmp_dir = vim.fn.tempname()
			vim.fn.mkdir(tmp_dir, "p")
			local file_path = tmp_dir .. "/2026-06-02.md"
			vim.fn.writefile({ "content" }, file_path)

			-- setup_test re-raises on a failing assertion inside test_fn, so
			-- deleting tmp_dir has to happen via pcall here too -- otherwise a
			-- failing assertion below would skip the cleanup on its way out
			-- and leak the temp directory.
			local ok, err = pcall(function()
				setup_test({
					config = { base_dir = tmp_dir .. "/", file_path = "%Y-%m-%d.md" },
				}, function()
					vim.cmd("edit " .. file_path)
					local buf = vim.api.nvim_get_current_buf()

					assert.is_true(vim.b[buf].jjournal_entry)
					assert.are.equal("2026-06-02", vim.b[buf].jjournal_date)

					vim.cmd("bwipeout! " .. buf)
				end)
			end)

			vim.fn.delete(tmp_dir, "rf")
			if not ok then error(err, 0) end
		end)

		it("still tags a real buffer for a nested file_path layout via a real, unmocked autocmd", function()
			local tmp_dir = vim.fn.tempname()
			local nested_dir = tmp_dir .. "/2026/06"
			vim.fn.mkdir(nested_dir, "p")
			local file_path = nested_dir .. "/2026-06-02.md"
			vim.fn.writefile({ "content" }, file_path)

			-- See the pcall note in the flat-layout spec above -- same reason.
			local ok, err = pcall(function()
				setup_test({
					config = { base_dir = tmp_dir .. "/", file_path = "%Y/%m/%Y-%m-%d.md" },
				}, function()
					vim.cmd("edit " .. file_path)
					local buf = vim.api.nvim_get_current_buf()

					assert.is_true(vim.b[buf].jjournal_entry)
					assert.are.equal("2026-06-02", vim.b[buf].jjournal_date)

					vim.cmd("bwipeout! " .. buf)
				end)
			end)

			vim.fn.delete(tmp_dir, "rf")
			if not ok then error(err, 0) end
		end)

		-- Step, skip, and pin only mean something for a buffer jjournal
		-- actually manages, so unlike the rest of the default mappings, each
		-- buffer_local entry is bound per-buffer from this same autocmd rather
		-- than globally at setup() -- see "does not bind any buffer_local
		-- mapping globally" above.
		it("binds every buffer_local mapping when a journal buffer is opened, wired to execute the right target/cmd/count, with its desc", function()
			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			setup_test({
				api = { nvim_buf_get_name = "/virtual/test/journal/path/2026-07-10.md" },
				config = { use_default_mappings = true },
				keymap = { set = true },
				jjournal = { execute = true },
			}, function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				for lhs, spec in pairs(jjournal.mappings) do
					if spec ~= false and spec.buffer_local then
						local matched
						for _, call in ipairs(vim.keymap.set.calls) do
							if call.vals[1] == "n" and call.vals[2] == lhs then
								matched = call
								break
							end
						end

						assert.is_not_nil(matched, "expected a buffer-local keymap.set call for " .. lhs)
						assert.are.same({ desc = spec.desc, silent = true, buffer = buf }, matched.vals[4])

						matched.vals[3]() -- invoke the bound handler as if the key had been pressed
						assert.stub(jjournal.execute).was_called_with(spec.target, spec.cmd, vim.v.count1)
					end
				end

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("does not bind buffer-local mappings when use_default_mappings is false", function()
			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			setup_test({
				api = { nvim_buf_get_name = "/virtual/test/journal/path/2026-07-10.md" },
				keymap = { set = true },
			}, function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				assert.stub(vim.keymap.set).was_not_called()

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("skips binding a buffer-local mapping that has been explicitly disabled with false", function()
			local original_spec = jjournal.mappings["<leader>jp"]
			jjournal.mappings["<leader>jp"] = false

			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			local ok, err = pcall(function()
				setup_test({
					api = { nvim_buf_get_name = "/virtual/test/journal/path/2026-07-10.md" },
					config = { use_default_mappings = true },
					keymap = { set = true },
				}, function()
					local buf = vim.api.nvim_create_buf(false, true)

					callback({ buf = buf })

					-- use_default_mappings = true means the global, non-buffer_local
					-- mappings are already bound by this point (see setup_test), so
					-- zero total calls isn't the right assertion here -- only that
					-- none of them are the disabled buffer-local one.
					for _, call in ipairs(vim.keymap.set.calls) do
						assert.are_not.equal("<leader>jp", call.vals[2])
					end

					vim.api.nvim_buf_delete(buf, { force = true })
				end)
			end)

			jjournal.mappings["<leader>jp"] = original_spec
			if not ok then error(err, 0) end
		end)
	end)

	describe("buffer cleanup and pinning autocmds", function()
		it("registers a TextChanged/TextChangedI autocmd scoped recursively to the configured journal path", function()
			setup_test({ api = { nvim_create_autocmd = true } }, function()
				local events = vim.api.nvim_create_autocmd.calls[2].vals[1]
				local opts = vim.api.nvim_create_autocmd.calls[2].vals[2]
				assert.are.same({ "TextChanged", "TextChangedI" }, events)
				assert.are.equal("/virtual/test/journal/path/**.md", opts.pattern)
			end)
		end)

		it("pins a buffer the moment its text changes", function()
			local callback = capture_autocmd_callback({ "TextChanged", "TextChangedI" })
			setup_test(nil, function()
				local buf = vim.api.nvim_create_buf(false, false)

				callback({ buf = buf })

				assert.is_true(vim.b[buf].jjournal_pinned)

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("registers a BufWinLeave autocmd scoped recursively to the configured journal path", function()
			setup_test({ api = { nvim_create_autocmd = true } }, function()
				assert.stub(vim.api.nvim_create_autocmd).was_called(4)
				local events = vim.api.nvim_create_autocmd.calls[3].vals[1]
				local opts = vim.api.nvim_create_autocmd.calls[3].vals[2]
				assert.are.equal("BufWinLeave", events)
				assert.are.equal("/virtual/test/journal/path/**.md", opts.pattern)
			end)
		end)

		-- None of these use scratch buffers (nvim_create_buf's second arg):
		-- real journal buffers, created in production via :edit, are never
		-- scratch buffers, and scratch buffers are documented to always
		-- report 'nomodified' regardless of content -- so a scratch buffer
		-- would leave the "edited, saved, then left" spec below unable to
		-- exercise the case it's meant to (a real edit happening at all).
		-- The actual wipe is deferred via vim.schedule (see register_autocmds),
		-- so each spec below gives the event loop a tick via vim.wait after
		-- invoking the callback, before asserting on the outcome.
		it("wipes an unedited, unpinned buffer once it's no longer displayed anywhere, whether or not the file existed before opening", function()
			local callback = capture_autocmd_callback("BufWinLeave")
			setup_test({ fn = { win_findbuf = {} } }, function()
				local buf = vim.api.nvim_create_buf(false, false)

				callback({ buf = buf })
				vim.wait(20)

				assert.is_false(vim.api.nvim_buf_is_valid(buf))
			end)
		end)

		it("does not wipe a buffer that was edited at any point this visit, even though 'modified' is currently false", function()
			local pin_callback = capture_autocmd_callback({ "TextChanged", "TextChangedI" })
			local leave_callback = capture_autocmd_callback("BufWinLeave")
			setup_test({ fn = { win_findbuf = {} } }, function()
				local buf = vim.api.nvim_create_buf(false, false)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "written and saved" })

				pin_callback({ buf = buf }) -- the edit itself would have fired this
				vim.api.nvim_buf_set_option(buf, "modified", false) -- simulates :w

				leave_callback({ buf = buf })
				vim.wait(20)

				assert.is_true(vim.api.nvim_buf_is_valid(buf))

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("does not wipe a buffer explicitly pinned via pin_buffer, even though it was never edited", function()
			local leave_callback = capture_autocmd_callback("BufWinLeave")
			setup_test({ fn = { win_findbuf = {} } }, function()
				local buf = vim.api.nvim_create_buf(false, false)
				vim.api.nvim_set_current_buf(buf)
				jjournal.pin_buffer()

				leave_callback({ buf = buf })
				vim.wait(20)

				assert.is_true(vim.api.nvim_buf_is_valid(buf))

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("does not wipe a buffer still displayed in another window", function()
			local callback = capture_autocmd_callback("BufWinLeave")
			setup_test({ fn = { win_findbuf = { 1001 } } }, function()
				local buf = vim.api.nvim_create_buf(false, false)

				callback({ buf = buf })
				vim.wait(20)

				assert.is_true(vim.api.nvim_buf_is_valid(buf))

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)
	end)

	describe("just-in-time directory creation", function()
		it("registers a BufWritePre autocmd scoped recursively to the configured journal path", function()
			setup_test({ api = { nvim_create_autocmd = true } }, function()
				local events = vim.api.nvim_create_autocmd.calls[4].vals[1]
				local opts = vim.api.nvim_create_autocmd.calls[4].vals[2]
				assert.are.equal("BufWritePre", events)
				assert.are.equal("/virtual/test/journal/path/**.md", opts.pattern)
			end)
		end)

		it("creates the parent directory when it doesn't exist yet, just before the write", function()
			local callback = capture_autocmd_callback("BufWritePre")
			setup_test({
				fn = { isdirectory = 0, mkdir = true },
			}, function()
				callback({ buf = 0, file = "/virtual/test/journal/path/2026/07/2026-07-09.md" })

				assert.stub(vim.fn.mkdir).was_called_with("/virtual/test/journal/path/2026/07", "p")
			end)
		end)

		it("does not create the directory when it already exists", function()
			local callback = capture_autocmd_callback("BufWritePre")
			setup_test({
				-- filewritable = 2 keeps this test's own setup() call from
				-- also tripping the base_dir-writability warning (see "base_dir
				-- validation" above) as an unrelated side effect -- isdirectory
				-- = 1 here means the base_dir check treats it as already
				-- existing, so without this it would fall through to a real,
				-- unmocked filewritable() call against a nonexistent path.
				fn = { isdirectory = 1, filewritable = 2, mkdir = true },
			}, function()
				callback({ buf = 0, file = "/virtual/test/journal/path/2026-07-09.md" })

				assert.stub(vim.fn.mkdir).was_not_called()
			end)
		end)

		-- Deliberately real and unmocked, in the style of the flat/nested
		-- autocmd-pattern tests in fix-autocmd-pattern-for-flat-layouts.md: a
		-- mocked BufWritePre callback invocation would prove the mkdir call
		-- happens, but not that a real :write against a genuinely missing
		-- directory actually succeeds afterward -- that's the real Neovim
		-- behavior this design depends on (verified empirically against real
		-- Vim before implementing: :edit succeeds regardless of whether the
		-- parent directory exists; only :write needs it to).
		it("lets a real :write succeed for a real file whose parent directory doesn't exist yet", function()
			local tmp_dir = vim.fn.tempname()
			vim.fn.mkdir(tmp_dir, "p")
			local file_path = tmp_dir .. "/2026/07/2026-07-09.md"

			local ok, err = pcall(function()
				setup_test({
					config = { base_dir = tmp_dir .. "/", file_path = "%Y/%m/%Y-%m-%d.md" },
				}, function()
					vim.cmd("edit " .. file_path)
					assert.are.equal(0, vim.fn.isdirectory(tmp_dir .. "/2026/07"))

					vim.cmd("write")

					assert.are.equal(1, vim.fn.isdirectory(tmp_dir .. "/2026/07"))
					assert.are.equal(1, vim.fn.filereadable(file_path))

					vim.cmd("bwipeout! " .. vim.api.nvim_get_current_buf())
				end)
			end)

			vim.fn.delete(tmp_dir, "rf")
			if not ok then error(err, 0) end
		end)
	end)
end)
