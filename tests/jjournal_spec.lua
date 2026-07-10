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

	it("defaults file_path to the flat 'YYYY-MM-DD.md' layout", function()
		package.loaded["jjournal"] = nil
		local fresh = require("jjournal")
		package.loaded["jjournal"] = jjournal

		assert.are.equal("%Y-%m-%d.md", fresh.config.file_path)
	end)

	it("normalizes a configured path that has no trailing slash", function()
		local cleanup = setup_test({
			config = { base_dir = "/virtual/test/no-trailing-slash" },
			fn = { isdirectory = 1 },
			vim = { cmd = true },
		})

		jjournal.open_date("2026-07-09", "edit")

		assert.stub(vim.cmd).was_called_with("edit /virtual/test/no-trailing-slash/2026-07-09.md")

		cleanup()
	end)
end)

describe("jjournal.resolve_date", function()
	-- Chronological-stepping specs need the current buffer to be inside the
	-- configured journal path, so the path-scoping check in
	-- get_current_date_coordinate treats it as the navigation anchor; only
	-- fn (glob/expand) is what each of those specs is actually testing.
	-- Override api.nvim_buf_get_name to move the buffer itself.
	local function setup_resolve_date_test(overrides)
		return setup_test(vim.tbl_deep_extend("force", {
			api = { nvim_buf_get_name = "/virtual/test/journal/path/current.md" },
		}, overrides or {}))
	end

	it("resolves 'today' to today's date", function()
		local cleanup = setup_test()
		local expected_today = vim.fn.strftime("%F")

		jjournal.resolve_date("today", function(resolved_date)
			assert.are.equal(expected_today, resolved_date)
		end)

		cleanup()
	end)

	it("resolves 'next' by stepping forward across empty days to the next existing entry", function()
		local cleanup = setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-01.md",
			},
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.are.equal("2026-06-03", resolved_date)
		end)

		cleanup()
	end)

	it("prioritizes virtual unwritten buffers over disk storage when resolving 'next'", function()
		local cleanup = setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-01.md",
			},
			api = {
				nvim_list_bufs = { 101, 102 },
				nvim_buf_is_loaded = true,
				nvim_buf_get_name = "/virtual/test/journal/path/2026-06-02.md",
			},
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.are.equal("2026-06-02", resolved_date)
		end)

		cleanup()
	end)

	it("resolves 'next' to nil when there is no later entry", function()
		local cleanup = setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-02.md" },
				expand = "2026-06-02.md",
			},
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.is_nil(resolved_date)
		end)

		cleanup()
	end)

	it("resolves 'prev' by stepping backward across empty days to the previous existing entry", function()
		local cleanup = setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-03.md",
			},
		})

		jjournal.resolve_date("prev", function(resolved_date)
			assert.are.equal("2026-06-01", resolved_date)
		end)

		cleanup()
	end)

	it("falls back to today when the current buffer is date-named but outside the journal path", function()
		local cleanup = setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-02.md",
				strftime = "2026-07-10",
			},
			api = { nvim_buf_get_name = "/some/other/notes/2026-06-02.md" },
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.is_nil(resolved_date)
		end)

		cleanup()
	end)

	it("falls back to today when the buffer's directory merely shares a name prefix with the journal path", function()
		-- "/virtual/test/journal/path-other" is NOT a descendant of
		-- "/virtual/test/journal/path", even though it shares a string prefix.
		local cleanup = setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-02.md",
				strftime = "2026-07-10",
			},
			api = { nvim_buf_get_name = "/virtual/test/journal/path-other/2026-06-02.md" },
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.is_nil(resolved_date)
		end)

		cleanup()
	end)

	it("treats a buffer nested under a subdirectory of the journal path as inside it", function()
		local cleanup = setup_resolve_date_test({
			fn = {
				glob = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-01.md",
			},
			api = { nvim_buf_get_name = "/virtual/test/journal/path/2026/06/2026-06-01.md" },
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.are.equal("2026-06-03", resolved_date)
		end)

		cleanup()
	end)

	it("discovers nested, non-.md journal files by extracting the date from an arbitrary filename", function()
		local cleanup = setup_resolve_date_test({
			fn = {
				glob = {
					"/virtual/test/journal/path/2026/06/journal-2026-06-01.txt",
					"/virtual/test/journal/path/2026/06/journal-2026-06-03.txt",
				},
				expand = "journal-2026-06-01.txt",
			},
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.are.equal("2026-06-03", resolved_date)
		end)

		cleanup()
	end)

	it("resolves 'prompt' by delegating to prompt_for_date", function()
		local cleanup = setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
		})

		local received
		jjournal.resolve_date("prompt", function(date)
			received = date
		end)

		assert.are.equal("2026-07-09", received)

		cleanup()
	end)
end)

describe("jjournal.resolve_path", function()
	it("resolves the default template the same as the previous flat layout", function()
		local cleanup = setup_test()

		assert.are.equal("/virtual/test/journal/path/2026-07-09.md", jjournal.resolve_path("2026-07-09"))

		cleanup()
	end)

	it("resolves %Y/%m/%d placeholders against a nested template", function()
		local cleanup = setup_test({ config = { file_path = "%Y/%m/%Y-%m-%d.md" } })

		assert.are.equal("/virtual/test/journal/path/2026/07/2026-07-09.md", jjournal.resolve_path("2026-07-09"))

		cleanup()
	end)

	it("resolves %D as shorthand for the full date alongside individual %Y/%m/%d tokens", function()
		local cleanup = setup_test({ config = { file_path = "%Y/%m/%d/journal-%D.txt" } })

		assert.are.equal(
			"/virtual/test/journal/path/2026/07/09/journal-2026-07-09.txt",
			jjournal.resolve_path("2026-07-09")
		)

		cleanup()
	end)
end)

describe("jjournal.prompt_for_date", function()
	it("invokes the callback with user input", function()
		local cleanup = setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
		})

		local received
		jjournal.prompt_for_date(function(date)
			received = date
		end)

		assert.are.equal("2026-07-09", received)

		cleanup()
	end)

	it("does not invoke the callback when the prompt is cancelled", function()
		local cleanup = setup_test({
			ui = { input = function(_, callback) callback(nil) end },
		})

		local was_called = false
		jjournal.prompt_for_date(function()
			was_called = true
		end)

		assert.is_false(was_called)

		cleanup()
	end)
end)

describe("jjournal.open_date", function()
	-- Most specs here just need the parent directory to already exist, so the
	-- mkdir check added for directory auto-creation is a no-op; override
	-- individual fields (e.g. fn.isdirectory) to exercise other paths.
	local function setup_open_date_test(overrides)
		return setup_test(vim.tbl_deep_extend("force", {
			fn = { isdirectory = 1 },
			vim = { cmd = true },
		}, overrides or {}))
	end

	it("opens the resolved date with the given command", function()
		local cleanup = setup_open_date_test()

		jjournal.open_date("2026-07-09", "vsplit")

		assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-09.md")

		cleanup()
	end)

	it("defaults to 'edit' when no command is given", function()
		local cleanup = setup_open_date_test()

		jjournal.open_date("2026-07-09")

		assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026-07-09.md")

		cleanup()
	end)

	it("opens the file at the path resolved from a custom nested file_path", function()
		local cleanup = setup_open_date_test({ config = { file_path = "%Y/%m/%Y-%m-%d.md" } })

		jjournal.open_date("2026-07-09", "edit")

		assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026/07/2026-07-09.md")

		cleanup()
	end)

	it("warns and does not open anything when date_str is nil", function()
		local cleanup = setup_open_date_test({ vim = { notify = true } })

		jjournal.open_date(nil)

		assert.stub(vim.notify).was_called(1)
		assert.are.equal(vim.log.levels.WARN, vim.notify.calls[1].vals[2])
		assert.stub(vim.cmd).was_not_called()

		cleanup()
	end)

	it("creates the parent directory before opening, when it doesn't exist yet", function()
		local calls = {}
		local cleanup = setup_open_date_test({
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
		})

		jjournal.open_date("2026-07-09", "edit")

		assert.are.same({
			{ "mkdir", "/virtual/test/journal/path", "p" },
			{ "cmd", "edit /virtual/test/journal/path/2026-07-09.md" },
		}, calls)

		cleanup()
	end)

	it("does not create the parent directory when it already exists", function()
		local cleanup = setup_open_date_test({ fn = { mkdir = true } })

		jjournal.open_date("2026-07-09", "edit")

		assert.stub(vim.fn.mkdir).was_not_called()
		assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026-07-09.md")

		cleanup()
	end)
end)

describe("jjournal.search_backlog", function()
	it("uses telescope by default when it is available", function()
		local fake_builtin = { live_grep = function() end }
		package.loaded["telescope.builtin"] = fake_builtin

		local cleanup = setup_test({
			on = { { fake_builtin, "live_grep" } },
			vim = { notify = true },
		})

		jjournal.search_backlog()

		assert.stub(fake_builtin.live_grep).was_called(1)
		local call_args = fake_builtin.live_grep.calls[1].vals[1]
		assert.are.same({ "/virtual/test/journal/path/" }, call_args.search_dirs)
		assert.are.equal("Search Journal Backlog", call_args.prompt_title)
		assert.stub(vim.notify).was_not_called()

		package.loaded["telescope.builtin"] = nil
		cleanup()
	end)

	it("falls back to the builtin search silently in 'auto' mode when telescope is unavailable", function()
		local cleanup = setup_test({
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true, notify = true },
		})

		jjournal.search_backlog()

		assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.md")
		assert.stub(vim.cmd).was_called_with("copen")
		assert.stub(vim.notify).was_not_called()

		cleanup()
	end)

	it("warns and falls back to builtin when 'telescope' is explicitly requested but unavailable", function()
		local cleanup = setup_test({
			config = { search = "telescope" },
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true, notify = true },
		})

		jjournal.search_backlog()

		assert.stub(vim.notify).was_called(1)
		assert.are.equal(vim.log.levels.WARN, vim.notify.calls[1].vals[2])
		assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.md")

		cleanup()
	end)

	it("uses the builtin search when 'builtin' is explicitly configured, even if telescope is available", function()
		local fake_builtin = { live_grep = function() end }
		package.loaded["telescope.builtin"] = fake_builtin

		local cleanup = setup_test({
			config = { search = "builtin" },
			on = { { fake_builtin, "live_grep" } },
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true },
		})

		jjournal.search_backlog()

		assert.stub(fake_builtin.live_grep).was_not_called()
		assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.md")

		package.loaded["telescope.builtin"] = nil
		cleanup()
	end)

	it("scopes the builtin vimgrep recursively to the extension configured via file_path", function()
		local cleanup = setup_test({
			config = { search = "builtin", file_path = "%Y/%m/%d/journal-%D.txt" },
			ui = { input = function(_, callback) callback("todo") end },
			vim = { cmd = true },
		})

		jjournal.search_backlog()

		assert.stub(vim.cmd).was_called_with("vimgrep /todo/gj /virtual/test/journal/path/**/*.txt")

		cleanup()
	end)

	it("escapes slashes in the search term before building the vimgrep pattern", function()
		local cleanup = setup_test({
			config = { search = "builtin" },
			ui = { input = function(_, callback) callback("a/b") end },
			vim = { cmd = true },
		})

		jjournal.search_backlog()

		assert.stub(vim.cmd).was_called_with("vimgrep /a\\/b/gj /virtual/test/journal/path/**/*.md")
		assert.stub(vim.cmd).was_called_with("copen")

		cleanup()
	end)

	it("does not vimgrep when the search prompt is cancelled", function()
		local cleanup = setup_test({
			config = { search = "builtin" },
			ui = { input = function(_, callback) callback(nil) end },
			vim = { cmd = true },
		})

		jjournal.search_backlog()

		assert.stub(vim.cmd).was_not_called()

		cleanup()
	end)

	it("calls a function configured as config.search directly with the journal path", function()
		local received_path
		local cleanup = setup_test({
			config = {
				search = function(path)
					received_path = path
				end,
			},
		})

		jjournal.search_backlog()

		assert.are.equal("/virtual/test/journal/path/", received_path)

		cleanup()
	end)

	it("warns and does nothing for an unrecognized config.search value", function()
		local cleanup = setup_test({
			config = { search = "not-a-real-provider" },
			vim = { notify = true, cmd = true },
		})

		jjournal.search_backlog()

		assert.stub(vim.notify).was_called(1)
		assert.are.equal(vim.log.levels.WARN, vim.notify.calls[1].vals[2])
		assert.stub(vim.cmd).was_not_called()

		cleanup()
	end)
end)

describe("jjournal.execute", function()
	it("delegates to search_backlog for the 'search' target without resolving a date", function()
		local cleanup = setup_test({ jjournal = { search_backlog = true } })

		jjournal.execute("search")

		assert.stub(jjournal.search_backlog).was_called(1)

		cleanup()
	end)

	it("resolves and opens a date for non-search targets", function()
		local cleanup = setup_test({
			fn = { strftime = "2026-07-10", isdirectory = 1 },
			vim = { cmd = true },
		})

		jjournal.execute("today", "vsplit")

		assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-10.md")

		cleanup()
	end)

	it("prompts for a date and opens it in a vsplit for the 'prompt' target", function()
		local cleanup = setup_test({
			ui = { input = function(_, callback) callback("2026-07-09") end },
			fn = { isdirectory = 1 },
			vim = { cmd = true },
		})

		jjournal.execute("prompt", "vsplit")

		assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-09.md")

		cleanup()
	end)
end)

describe("jjournal.setup", function()
	-- Every spec here needs vim.keymap.set stubbed; override config to flip
	-- use_default_mappings on, or add other mocks, per test.
	local function setup_setup_test(overrides)
		return setup_test(vim.tbl_deep_extend("force", {
			keymap = { set = true },
		}, overrides or {}))
	end

	it("merges provided options over the existing config without clobbering unspecified keys", function()
		local cleanup = setup_setup_test()

		jjournal.setup({ use_default_mappings = true })

		assert.are.equal("/virtual/test/journal/path/", jjournal.config.base_dir)
		assert.is_true(jjournal.config.use_default_mappings)

		cleanup()
	end)

	it("includes a <leader>jJ mapping that prompts for a date and opens it in a vsplit", function()
		assert.are.same(
			{ target = "prompt", cmd = "vsplit", desc = "Jump to journal date (split)" },
			jjournal.mappings["<leader>jJ"]
		)
	end)

	it("binds every default mapping in normal mode, wired to execute the right target/cmd, with its desc", function()
		local cleanup = setup_setup_test({
			config = { use_default_mappings = true },
			jjournal = { execute = true },
		})

		local expected_count = 0
		for _ in pairs(jjournal.mappings) do
			expected_count = expected_count + 1
		end
		assert.stub(vim.keymap.set).was_called(expected_count)

		for lhs, spec in pairs(jjournal.mappings) do
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
			assert.stub(jjournal.execute).was_called_with(spec.target, spec.cmd)
		end

		cleanup()
	end)

	it("skips keymap binding entirely when use_default_mappings is false", function()
		local cleanup = setup_setup_test()

		assert.stub(vim.keymap.set).was_not_called()

		cleanup()
	end)

	it("skips binding an individual mapping that has been explicitly disabled with false", function()
		local original_spec = jjournal.mappings["gj"]
		jjournal.mappings["gj"] = false

		local cleanup = setup_setup_test({ config = { use_default_mappings = true } })

		for _, call in ipairs(vim.keymap.set.calls) do
			assert.are_not.equal("gj", call.vals[2])
		end

		jjournal.mappings["gj"] = original_spec
		cleanup()
	end)

	describe("file_path validation", function()
		it("errors when the filename portion has no way to recover the full date", function()
			assert.has_error(function()
				setup_test({ config = { file_path = "%Y/%m/%d.md" } })
			end)
		end)

		it("accepts a filename containing the literal %Y-%m-%d with an arbitrary prefix/suffix and extension", function()
			local cleanup = setup_test({ config = { file_path = "%Y/%m/notes-%Y-%m-%d-final.txt" } })
			cleanup()
		end)

		it("accepts a filename containing %D as shorthand for the full date", function()
			local cleanup = setup_test({ config = { file_path = "%Y/%m/%d/journal-%D.txt" } })
			cleanup()
		end)
	end)

	describe("journal buffer status autocmd", function()
		local function capture_autocmd_callback(overrides)
			local captured
			local cleanup = setup_test(vim.tbl_deep_extend("force", {
				api = {
					nvim_create_autocmd = function(_, opts)
						captured = opts.callback
					end,
				},
			}, overrides or {}))
			cleanup()
			return captured
		end

		it("registers a BufReadPost/BufNewFile autocmd scoped recursively to the configured journal path", function()
			local cleanup = setup_test({ api = { nvim_create_autocmd = true } })

			assert.stub(vim.api.nvim_create_autocmd).was_called(1)
			local events = vim.api.nvim_create_autocmd.calls[1].vals[1]
			local opts = vim.api.nvim_create_autocmd.calls[1].vals[2]
			assert.are.same({ "BufReadPost", "BufNewFile" }, events)
			assert.are.equal("/virtual/test/journal/path/**/*.md", opts.pattern)

			cleanup()
		end)

		it("scopes the autocmd pattern recursively to the extension configured via file_path", function()
			local cleanup = setup_test({
				api = { nvim_create_autocmd = true },
				config = { file_path = "%Y/%m/%d/journal-%D.txt" },
			})

			local opts = vim.api.nvim_create_autocmd.calls[1].vals[2]
			assert.are.equal("/virtual/test/journal/path/**/*.txt", opts.pattern)

			cleanup()
		end)

		-- "Today" is fixed at 2026-07-10 for both specs below; only the buffer's
		-- name (whether it matches today's date) varies between them.
		local function setup_status_test(buffer_name)
			return setup_test({
				fn = { strftime = "2026-07-10" },
				api = { nvim_buf_get_name = buffer_name },
			})
		end

		it("flags the buffer as today's journal when its name matches today's date", function()
			local callback = capture_autocmd_callback()
			local cleanup = setup_status_test("/virtual/test/journal/path/2026-07-10.md")
			local buf = vim.api.nvim_create_buf(false, true)

			callback({ buf = buf })

			assert.are.equal("today", vim.b[buf].journal_status)

			vim.api.nvim_buf_delete(buf, { force = true })
			cleanup()
		end)

		it("flags the buffer as an archived journal when its name does not match today's date", function()
			local callback = capture_autocmd_callback()
			local cleanup = setup_status_test("/virtual/test/journal/path/2026-06-01.md")
			local buf = vim.api.nvim_create_buf(false, true)

			callback({ buf = buf })

			assert.are.equal("archive", vim.b[buf].journal_status)

			vim.api.nvim_buf_delete(buf, { force = true })
			cleanup()
		end)

		it("resolves today's path via a custom nested file_path when flagging status", function()
			local nested_template = "%Y/%m/%Y-%m-%d.md"
			local callback = capture_autocmd_callback({ config = { file_path = nested_template } })
			local cleanup = setup_test({
				config = { file_path = nested_template },
				fn = { strftime = "2026-07-10" },
				api = { nvim_buf_get_name = "/virtual/test/journal/path/2026/07/2026-07-10.md" },
			})
			local buf = vim.api.nvim_create_buf(false, true)

			callback({ buf = buf })

			assert.are.equal("today", vim.b[buf].journal_status)

			vim.api.nvim_buf_delete(buf, { force = true })
			cleanup()
		end)
	end)
end)
