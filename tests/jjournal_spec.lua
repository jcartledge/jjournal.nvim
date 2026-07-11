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
			fn = { isdirectory = 1 },
			vim = { cmd = true },
		}, function()
			jjournal.open_date("2026-07-09", "edit")

			assert.stub(vim.cmd).was_called_with("edit /virtual/test/no-trailing-slash/2026-07-09.md")
		end)
	end)
end)

describe("jjournal.resolve_date", function()
	-- Chronological-stepping/skipping specs need the current buffer to be
	-- inside the configured journal path, so the path-scoping check in
	-- current_anchor_date treats it as the navigation anchor; fn.expand
	-- supplies the filename each spec navigates from. Neither step nor skip
	-- depends on "today" at all, so fn.strftime isn't part of the shared
	-- default -- it's only passed explicitly in the couple of specs that
	-- actually need it (the outside-journal-path fallback).
	local function setup_resolve_date_test(overrides, test_fn)
		setup_test(vim.tbl_deep_extend("force", {
			api = { nvim_buf_get_name = "/virtual/test/journal/path/current.md" },
		}, overrides or {}), test_fn)
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
		setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-01.md",
			},
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-06-03", resolved_date)
			end)
		end)
	end)

	it("prioritizes virtual unwritten buffers over disk storage when resolving 'skip_next'", function()
		setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-01.md",
			},
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
		setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-02.md" },
				expand = "2026-06-02.md",
			},
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.is_nil(resolved_date)
			end)
		end)
	end)

	it("resolves 'skip_prev' by skipping across empty days to the previous existing entry", function()
		setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-03.md",
			},
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
		setup_resolve_date_test({
			fn = {
				glob = { "2026-07-10.md", "2026-07-15.md" },
				expand = "2026-07-10.md",
			},
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-07-15", resolved_date)
			end)
		end)
	end)

	it("falls back to today when the current buffer is date-named but outside the journal path", function()
		setup_resolve_date_test({
			fn = { strftime = "2026-07-10" },
			api = { nvim_buf_get_name = "/some/other/notes/2026-06-02.md" },
		}, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-07-11", resolved_date)
			end)
		end)
	end)

	it("falls back to today when the buffer's directory merely shares a name prefix with the journal path", function()
		-- "/virtual/test/journal/path-other" is NOT a descendant of
		-- "/virtual/test/journal/path", even though it shares a string prefix.
		setup_resolve_date_test({
			fn = { strftime = "2026-07-10" },
			api = { nvim_buf_get_name = "/virtual/test/journal/path-other/2026-06-02.md" },
		}, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-07-11", resolved_date)
			end)
		end)
	end)

	it("treats a buffer nested under a subdirectory of the journal path as inside it", function()
		setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-01.md",
			},
			api = { nvim_buf_get_name = "/virtual/test/journal/path/2026/06/2026-06-01.md" },
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-06-03", resolved_date)
			end)
		end)
	end)

	it("discovers nested, non-.md journal files by extracting the date from an arbitrary filename", function()
		setup_resolve_date_test({
			fn = {
				glob = {
					"/virtual/test/journal/path/2026/06/journal-2026-06-01.txt",
					"/virtual/test/journal/path/2026/06/journal-2026-06-03.txt",
				},
				expand = "journal-2026-06-01.txt",
			},
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-06-03", resolved_date)
			end)
		end)
	end)

	it("steps forward exactly one day, creating the entry even if it doesn't exist yet", function()
		setup_resolve_date_test({
			fn = { expand = "2026-07-10.md" },
		}, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-07-11", resolved_date)
			end)
		end)
	end)

	it("steps backward exactly one day", function()
		setup_resolve_date_test({
			fn = { expand = "2026-07-11.md" },
		}, function()
			jjournal.resolve_date("step_prev", function(resolved_date)
				assert.are.equal("2026-07-10", resolved_date)
			end)
		end)
	end)

	-- Unlike the old today-relative hybrid, step behaves the same whether
	-- the result lands before or after today -- this previously would have
	-- fallen back to skip-searching instead.
	it("steps forward exactly one day even when the result lands before today", function()
		setup_resolve_date_test({
			fn = { expand = "2026-06-01.md" },
		}, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-06-02", resolved_date)
			end)
		end)
	end)

	it("shifts correctly across a year boundary", function()
		setup_resolve_date_test({
			fn = { expand = "2025-12-31.md" },
		}, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-01-01", resolved_date)
			end)
		end)
	end)

	it("steps forward N days when count-prefixed", function()
		setup_resolve_date_test({
			fn = { expand = "2026-07-10.md" },
		}, function()
			jjournal.resolve_date("step_next", function(resolved_date)
				assert.are.equal("2026-07-13", resolved_date)
			end, 3)
		end)
	end)

	it("steps backward N days when count-prefixed", function()
		setup_resolve_date_test({
			fn = { expand = "2026-07-13.md" },
		}, function()
			jjournal.resolve_date("step_prev", function(resolved_date)
				assert.are.equal("2026-07-10", resolved_date)
			end, 3)
		end)
	end)

	it("skips forward to the Nth existing entry when count-prefixed", function()
		setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md", "2026-06-05.md" },
				expand = "2026-06-01.md",
			},
		}, function()
			jjournal.resolve_date("skip_next", function(resolved_date)
				assert.are.equal("2026-06-05", resolved_date)
			end, 2)
		end)
	end)

	it("skips backward to the Nth existing entry when count-prefixed", function()
		setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md", "2026-06-05.md" },
				expand = "2026-06-05.md",
			},
		}, function()
			jjournal.resolve_date("skip_prev", function(resolved_date)
				assert.are.equal("2026-06-01", resolved_date)
			end, 2)
		end)
	end)

	it("resolves to nil when a count-prefixed skip requests more entries than exist", function()
		setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-01.md",
			},
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
	-- Most specs here just need the parent directory to already exist, so the
	-- mkdir check is a no-op; override fn.isdirectory to exercise that path.
	local function setup_open_date_test(overrides, test_fn)
		setup_test(vim.tbl_deep_extend("force", {
			fn = { isdirectory = 1 },
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

	it("creates the parent directory before opening, when it doesn't exist yet", function()
		local calls = {}
		setup_open_date_test({
			fn = {
				isdirectory = 0,
				mkdir = function(dir, flags)
					table.insert(calls, { "mkdir", dir, flags })
				end,
			},
			vim = {
				cmd = function(command)
					table.insert(calls, { "cmd", command })
				end,
			},
		}, function()
			jjournal.open_date("2026-07-09", "edit")

			assert.are.same({
				{ "mkdir", "/virtual/test/journal/path", "p" },
				{ "cmd", "edit /virtual/test/journal/path/2026-07-09.md" },
			}, calls)
		end)
	end)

	it("does not create the parent directory when it already exists", function()
		setup_open_date_test({ fn = { mkdir = true } }, function()
			jjournal.open_date("2026-07-09", "edit")

			assert.stub(vim.fn.mkdir).was_not_called()
			assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026-07-09.md")
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
			fn = { strftime = "2026-07-10", isdirectory = 1 },
			vim = { cmd = true },
		}, function()
			jjournal.execute("today", "vsplit")

			assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-10.md")
		end)
	end)

	it("prompts for a date and opens it in a vsplit for the 'prompt' target", function()
		setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
			fn = { isdirectory = 1 },
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
			fn = { strftime = "2026-07-10", isdirectory = 1 },
			vim = { cmd = true },
		}, function()
			jjournal.execute("today", "edit", 5)

			assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026-07-10.md")
		end)
	end)

	it("ignores a count prefix for the 'prompt' target", function()
		setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
			fn = { isdirectory = 1 },
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

	it("does not bind a buffer_local mapping globally", function()
		setup_setup_test({ config = { use_default_mappings = true } }, function()
			for _, call in ipairs(vim.keymap.set.calls) do
				assert.are_not.equal("<leader>jp", call.vals[2])
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

	describe("journal buffer status autocmd", function()
		it("registers a BufReadPost/BufNewFile autocmd scoped recursively to the configured journal path", function()
			setup_test({ api = { nvim_create_autocmd = true } }, function()
				-- Called three times total: this autocmd plus the pin-on-edit and
				-- BufWinLeave cleanup autocmds registered alongside it (see the
				-- "buffer cleanup and pinning autocmds" describe block below) --
				-- all three sharing the same augroup and pattern, registered in
				-- this order.
				assert.stub(vim.api.nvim_create_autocmd).was_called(3)
				local events = vim.api.nvim_create_autocmd.calls[1].vals[1]
				local opts = vim.api.nvim_create_autocmd.calls[1].vals[2]
				assert.are.same({ "BufReadPost", "BufNewFile" }, events)
				assert.are.equal("/virtual/test/journal/path/**/*.md", opts.pattern)
			end)
		end)

		it("scopes the autocmd pattern recursively to the extension configured via file_path", function()
			setup_test({
				api = { nvim_create_autocmd = true },
				config = { file_path = "%Y/%m/%d/journal-%D.txt" },
			}, function()
				local opts = vim.api.nvim_create_autocmd.calls[1].vals[2]
				assert.are.equal("/virtual/test/journal/path/**/*.txt", opts.pattern)
			end)
		end)

		-- "Today" is fixed at 2026-07-10 for both specs below; only the buffer's
		-- name (whether it matches today's date) varies between them.
		local function setup_status_test(buffer_name, test_fn)
			setup_test({
				fn = { strftime = "2026-07-10" },
				api = { nvim_buf_get_name = buffer_name },
			}, test_fn)
		end

		it("flags the buffer as today's journal when its name matches today's date", function()
			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			setup_status_test("/virtual/test/journal/path/2026-07-10.md", function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				assert.are.equal("today", vim.b[buf].journal_status)

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("flags the buffer as an archived journal when its name does not match today's date", function()
			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			setup_status_test("/virtual/test/journal/path/2026-06-01.md", function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				assert.are.equal("archive", vim.b[buf].journal_status)

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("resolves today's path via a custom nested file_path when flagging status", function()
			local nested_template = "%Y/%m/%Y-%m-%d.md"
			local callback =
				capture_autocmd_callback({ "BufReadPost", "BufNewFile" }, { config = { file_path = nested_template } })
			setup_test({
				config = { file_path = nested_template },
				fn = { strftime = "2026-07-10" },
				api = { nvim_buf_get_name = "/virtual/test/journal/path/2026/07/2026-07-10.md" },
			}, function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				assert.are.equal("today", vim.b[buf].journal_status)

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		-- Pinning only means something for a buffer jjournal actually manages,
		-- so unlike the rest of the default mappings, <leader>jp is bound
		-- per-buffer from this same autocmd rather than globally at setup() --
		-- see "does not bind a buffer_local mapping globally" above.
		it("binds buffer-local mappings when a journal buffer is opened, wired to execute the right target/cmd/count, with its desc", function()
			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			setup_test({
				fn = { strftime = "2026-07-10" },
				api = { nvim_buf_get_name = "/virtual/test/journal/path/2026-07-10.md" },
				config = { use_default_mappings = true },
				keymap = { set = true },
				jjournal = { execute = true },
			}, function()
				local buf = vim.api.nvim_create_buf(false, true)

				callback({ buf = buf })

				local matched
				for _, call in ipairs(vim.keymap.set.calls) do
					if call.vals[1] == "n" and call.vals[2] == "<leader>jp" then
						matched = call
						break
					end
				end

				assert.is_not_nil(matched, "expected a buffer-local keymap.set call for <leader>jp")
				assert.are.same(
					{ desc = jjournal.mappings["<leader>jp"].desc, silent = true, buffer = buf },
					matched.vals[4]
				)

				matched.vals[3]() -- invoke the bound handler as if the key had been pressed
				assert.stub(jjournal.execute).was_called_with("pin", nil, vim.v.count1)

				vim.api.nvim_buf_delete(buf, { force = true })
			end)
		end)

		it("does not bind buffer-local mappings when use_default_mappings is false", function()
			local callback = capture_autocmd_callback({ "BufReadPost", "BufNewFile" })
			setup_test({
				fn = { strftime = "2026-07-10" },
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
					fn = { strftime = "2026-07-10" },
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
				assert.are.equal("/virtual/test/journal/path/**/*.md", opts.pattern)
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
				assert.stub(vim.api.nvim_create_autocmd).was_called(3)
				local events = vim.api.nvim_create_autocmd.calls[3].vals[1]
				local opts = vim.api.nvim_create_autocmd.calls[3].vals[2]
				assert.are.equal("BufWinLeave", events)
				assert.are.equal("/virtual/test/journal/path/**/*.md", opts.pattern)
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
end)
