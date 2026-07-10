local jjournal = require("jjournal")
local assert = require("luassert")
local setup_test = require("support.setup_test")

describe("jjournal config", function()
	it("defaults to '~/notes/journals/' with default mappings enabled before setup() is called", function()
		package.loaded["jjournal"] = nil
		local fresh = require("jjournal")
		package.loaded["jjournal"] = jjournal -- restore the shared instance used by the rest of the suite

		assert.are.equal(vim.fn.expand("~/notes/journals/"), fresh.config.path)
		assert.is_true(fresh.config.use_default_mappings)
	end)

	it("normalizes a configured path that has no trailing slash", function()
		local cleanup = setup_test({
			config = { path = "/virtual/test/no-trailing-slash" },
			vim = { cmd = true },
		})

		jjournal.open_date("2026-07-09", "edit")

		assert.stub(vim.cmd).was_called_with("edit /virtual/test/no-trailing-slash/2026-07-09.md")

		cleanup()
	end)
end)

describe("jjournal.resolve_date", function()
	it("resolves 'today' to today's date", function()
		local cleanup = setup_test()
		local expected_today = vim.fn.strftime("%F")

		jjournal.resolve_date("today", function(resolved_date)
			assert.are.equal(expected_today, resolved_date)
		end)

		cleanup()
	end)

	it("resolves 'next' by stepping forward across empty days to the next existing entry", function()
		local cleanup = setup_test({
			fn = {
				readdir = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-01.md",
			},
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.are.equal("2026-06-03", resolved_date)
		end)

		cleanup()
	end)

	it("prioritizes virtual unwritten buffers over disk storage when resolving 'next'", function()
		local cleanup = setup_test({
			fn = {
				readdir = { "2026-06-01.md", "2026-06-03.md" },
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
		local cleanup = setup_test({
			fn = {
				readdir = { "2026-06-01.md", "2026-06-02.md" },
				expand = "2026-06-02.md",
			},
		})

		jjournal.resolve_date("next", function(resolved_date)
			assert.is_nil(resolved_date)
		end)

		cleanup()
	end)

	it("resolves 'prev' by stepping backward across empty days to the previous existing entry", function()
		local cleanup = setup_test({
			fn = {
				readdir = { "2026-06-01.md", "2026-06-03.md" },
				expand = "2026-06-03.md",
			},
		})

		jjournal.resolve_date("prev", function(resolved_date)
			assert.are.equal("2026-06-01", resolved_date)
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
	it("opens the resolved date with the given command", function()
		local cleanup = setup_test({ vim = { cmd = true } })

		jjournal.open_date("2026-07-09", "vsplit")

		assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-09.md")

		cleanup()
	end)

	it("defaults to 'edit' when no command is given", function()
		local cleanup = setup_test({ vim = { cmd = true } })

		jjournal.open_date("2026-07-09")

		assert.stub(vim.cmd).was_called_with("edit /virtual/test/journal/path/2026-07-09.md")

		cleanup()
	end)

	it("warns and does not open anything when date_str is nil", function()
		local cleanup = setup_test({ vim = { notify = true, cmd = true } })

		jjournal.open_date(nil)

		assert.stub(vim.notify).was_called(1)
		assert.are.equal(vim.log.levels.WARN, vim.notify.calls[1].vals[2])
		assert.stub(vim.cmd).was_not_called()

		cleanup()
	end)
end)

describe("jjournal.search_backlog", function()
	it("delegates to telescope's live_grep with the configured path", function()
		local fake_builtin = { live_grep = function() end }
		package.loaded["telescope.builtin"] = fake_builtin

		local cleanup = setup_test({ on = { { fake_builtin, "live_grep" } } })

		jjournal.search_backlog()

		assert.stub(fake_builtin.live_grep).was_called(1)
		local call_args = fake_builtin.live_grep.calls[1].vals[1]
		assert.are.same({ "/virtual/test/journal/path/" }, call_args.search_dirs)
		assert.are.equal("Search Journal Backlog", call_args.prompt_title)

		package.loaded["telescope.builtin"] = nil
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
			fn = { strftime = "2026-07-10" },
			vim = { cmd = true },
		})

		jjournal.execute("today", "vsplit")

		assert.stub(vim.cmd).was_called_with("vsplit /virtual/test/journal/path/2026-07-10.md")

		cleanup()
	end)
end)

describe("jjournal.setup", function()
	it("merges provided options over the existing config without clobbering unspecified keys", function()
		local cleanup = setup_test({ keymap = { set = true } })

		jjournal.setup({ use_default_mappings = true })

		assert.are.equal("/virtual/test/journal/path/", jjournal.config.path)
		assert.is_true(jjournal.config.use_default_mappings)

		cleanup()
	end)

	it("binds every default mapping in normal mode, wired to execute the right target/cmd, with its desc", function()
		local cleanup = setup_test({
			config = { use_default_mappings = true },
			keymap = { set = true },
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
		local cleanup = setup_test({ keymap = { set = true } })

		assert.stub(vim.keymap.set).was_not_called()

		cleanup()
	end)

	it("skips binding an individual mapping that has been explicitly disabled with false", function()
		local original_spec = jjournal.mappings["gj"]
		jjournal.mappings["gj"] = false

		local cleanup = setup_test({
			config = { use_default_mappings = true },
			keymap = { set = true },
		})

		for _, call in ipairs(vim.keymap.set.calls) do
			assert.are_not.equal("gj", call.vals[2])
		end

		jjournal.mappings["gj"] = original_spec
		cleanup()
	end)

	describe("journal buffer status autocmd", function()
		local function capture_autocmd_callback()
			local captured
			local cleanup = setup_test({
				api = {
					nvim_create_autocmd = function(_, opts)
						captured = opts.callback
					end,
				},
			})
			cleanup()
			return captured
		end

		it("registers a BufReadPost/BufNewFile autocmd scoped to the configured journal path", function()
			local cleanup = setup_test({ api = { nvim_create_autocmd = true } })

			assert.stub(vim.api.nvim_create_autocmd).was_called(1)
			local events = vim.api.nvim_create_autocmd.calls[1].vals[1]
			local opts = vim.api.nvim_create_autocmd.calls[1].vals[2]
			assert.are.same({ "BufReadPost", "BufNewFile" }, events)
			assert.are.equal("/virtual/test/journal/path/*.md", opts.pattern)

			cleanup()
		end)

		it("flags the buffer as today's journal when its name matches today's date", function()
			local callback = capture_autocmd_callback()
			local cleanup = setup_test({
				fn = { strftime = "2026-07-10" },
				api = { nvim_buf_get_name = "/virtual/test/journal/path/2026-07-10.md" },
			})
			local buf = vim.api.nvim_create_buf(false, true)

			callback({ buf = buf })

			assert.are.equal("today", vim.b[buf].journal_status)

			vim.api.nvim_buf_delete(buf, { force = true })
			cleanup()
		end)

		it("flags the buffer as an archived journal when its name does not match today's date", function()
			local callback = capture_autocmd_callback()
			local cleanup = setup_test({
				fn = { strftime = "2026-07-10" },
				api = { nvim_buf_get_name = "/virtual/test/journal/path/2026-06-01.md" },
			})
			local buf = vim.api.nvim_create_buf(false, true)

			callback({ buf = buf })

			assert.are.equal("archive", vim.b[buf].journal_status)

			vim.api.nvim_buf_delete(buf, { force = true })
			cleanup()
		end)
	end)
end)
