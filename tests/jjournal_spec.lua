local jjournal = require("jjournal")
local assert = require("luassert")
local stub = require("luassert.stub")

local function setup_test(mocks)
	mocks = mocks or {}

	jjournal.setup({
		path = "/virtual/test/journal/path/",
		use_default_mappings = false,
	})

	local active_stubs = {}

	if mocks.fn then
		for func_name, return_value in pairs(mocks.fn) do
			table.insert(active_stubs, stub(vim.fn, func_name, return_value))
		end
	end

	if mocks.api then
		for func_name, return_value in pairs(mocks.api) do
			table.insert(active_stubs, stub(vim.api, func_name, return_value))
		end
	end

	return function()
		for _, s in ipairs(active_stubs) do
			s:revert()
		end
	end
end

describe("jjournal.resolve_date", function()
	it("resolves 'today' to today's date", function()
		setup_test()
		local expected_today = vim.fn.strftime("%F")

		jjournal.resolve_date("today", function(resolved_date)
			assert.are.equal(expected_today, resolved_date)
		end)
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
		local cleanup = setup_test()
		local input_stub = stub(vim.ui, "input").invokes(function(_, callback)
			callback("2026-07-09")
		end)

		local received
		jjournal.resolve_date("prompt", function(date)
			received = date
		end)

		assert.are.equal("2026-07-09", received)

		input_stub:revert()
		cleanup()
	end)
end)

describe("jjournal.prompt_for_date", function()
	it("invokes the callback with user input", function()
		local cleanup = setup_test()
		local input_stub = stub(vim.ui, "input").invokes(function(_, callback)
			callback("2026-07-09")
		end)

		local received
		jjournal.prompt_for_date(function(date)
			received = date
		end)

		assert.are.equal("2026-07-09", received)

		input_stub:revert()
		cleanup()
	end)

	it("does not invoke the callback when the prompt is cancelled", function()
		local cleanup = setup_test()
		local input_stub = stub(vim.ui, "input").invokes(function(_, callback)
			callback(nil)
		end)

		local was_called = false
		jjournal.prompt_for_date(function()
			was_called = true
		end)

		assert.is_false(was_called)

		input_stub:revert()
		cleanup()
	end)
end)

describe("jjournal.open_date", function()
	it("opens the resolved date with the given command", function()
		local cleanup = setup_test()
		local cmd_stub = stub(vim, "cmd")

		jjournal.open_date("2026-07-09", "vsplit")

		assert.stub(cmd_stub).was_called_with("vsplit /virtual/test/journal/path/2026-07-09.md")

		cmd_stub:revert()
		cleanup()
	end)

	it("defaults to 'edit' when no command is given", function()
		local cleanup = setup_test()
		local cmd_stub = stub(vim, "cmd")

		jjournal.open_date("2026-07-09")

		assert.stub(cmd_stub).was_called_with("edit /virtual/test/journal/path/2026-07-09.md")

		cmd_stub:revert()
		cleanup()
	end)

	it("warns and does not open anything when date_str is nil", function()
		local cleanup = setup_test()
		local notify_stub = stub(vim, "notify")
		local cmd_stub = stub(vim, "cmd")

		jjournal.open_date(nil)

		assert.stub(notify_stub).was_called(1)
		assert.are.equal(vim.log.levels.WARN, notify_stub.calls[1].vals[2])
		assert.stub(cmd_stub).was_not_called()

		notify_stub:revert()
		cmd_stub:revert()
		cleanup()
	end)
end)

describe("jjournal.search_backlog", function()
	it("delegates to telescope's live_grep with the configured path", function()
		local cleanup = setup_test()
		local fake_builtin = { live_grep = function() end }
		package.loaded["telescope.builtin"] = fake_builtin
		local live_grep_stub = stub(fake_builtin, "live_grep")

		jjournal.search_backlog()

		assert.stub(live_grep_stub).was_called(1)
		local call_args = live_grep_stub.calls[1].vals[1]
		assert.are.same({ "/virtual/test/journal/path/" }, call_args.search_dirs)

		package.loaded["telescope.builtin"] = nil
		cleanup()
	end)
end)

describe("jjournal.execute", function()
	it("delegates to search_backlog for the 'search' target without resolving a date", function()
		local cleanup = setup_test()
		local search_stub = stub(jjournal, "search_backlog")

		jjournal.execute("search")

		assert.stub(search_stub).was_called(1)

		search_stub:revert()
		cleanup()
	end)

	it("resolves and opens a date for non-search targets", function()
		local cleanup = setup_test({ fn = { strftime = "2026-07-10" } })
		local cmd_stub = stub(vim, "cmd")

		jjournal.execute("today", "vsplit")

		assert.stub(cmd_stub).was_called_with("vsplit /virtual/test/journal/path/2026-07-10.md")

		cmd_stub:revert()
		cleanup()
	end)
end)

describe("jjournal.setup", function()
	it("merges provided options over the existing config without clobbering unspecified keys", function()
		local keymap_stub = stub(vim.keymap, "set")

		jjournal.setup({ path = "/virtual/test/journal/path/", use_default_mappings = false })
		jjournal.setup({ use_default_mappings = true })

		assert.are.equal("/virtual/test/journal/path/", jjournal.config.path)
		assert.is_true(jjournal.config.use_default_mappings)

		keymap_stub:revert()
	end)

	it("binds default keymaps when use_default_mappings is true", function()
		local keymap_stub = stub(vim.keymap, "set")

		jjournal.setup({ path = "/virtual/test/journal/path/", use_default_mappings = true })

		local expected_count = 0
		for _ in pairs(jjournal.mappings) do
			expected_count = expected_count + 1
		end
		assert.stub(keymap_stub).was_called(expected_count)

		keymap_stub:revert()
	end)

	it("skips keymap binding when use_default_mappings is false", function()
		local keymap_stub = stub(vim.keymap, "set")

		jjournal.setup({ path = "/virtual/test/journal/path/", use_default_mappings = false })

		assert.stub(keymap_stub).was_not_called()

		keymap_stub:revert()
	end)

	describe("journal buffer status autocmd", function()
		local function setup_with_autocmd_capture()
			local original = vim.api.nvim_create_autocmd
			local captured

			vim.api.nvim_create_autocmd = function(events, autocmd_opts)
				captured = autocmd_opts.callback
				return original(events, autocmd_opts)
			end

			jjournal.setup({ path = "/virtual/test/journal/path/", use_default_mappings = false })

			vim.api.nvim_create_autocmd = original
			return captured
		end

		it("registers a BufReadPost/BufNewFile autocmd scoped to the configured journal path", function()
			local autocmd_stub = stub(vim.api, "nvim_create_autocmd")

			jjournal.setup({ path = "/virtual/test/journal/path/", use_default_mappings = false })

			assert.stub(autocmd_stub).was_called(1)
			local events = autocmd_stub.calls[1].vals[1]
			local opts = autocmd_stub.calls[1].vals[2]
			assert.are.same({ "BufReadPost", "BufNewFile" }, events)
			assert.are.equal("/virtual/test/journal/path/*.md", opts.pattern)

			autocmd_stub:revert()
		end)

		it("flags the buffer as today's journal when its name matches today's date", function()
			local strftime_stub = stub(vim.fn, "strftime", "2026-07-10")
			local callback = setup_with_autocmd_capture()
			local buf_name_stub = stub(vim.api, "nvim_buf_get_name", "/virtual/test/journal/path/2026-07-10.md")
			local buf = vim.api.nvim_create_buf(false, true)

			callback({ buf = buf })

			assert.are.equal("today", vim.b[buf].journal_status)

			vim.api.nvim_buf_delete(buf, { force = true })
			buf_name_stub:revert()
			strftime_stub:revert()
		end)

		it("flags the buffer as an archived journal when its name does not match today's date", function()
			local strftime_stub = stub(vim.fn, "strftime", "2026-07-10")
			local callback = setup_with_autocmd_capture()
			local buf_name_stub = stub(vim.api, "nvim_buf_get_name", "/virtual/test/journal/path/2026-06-01.md")
			local buf = vim.api.nvim_create_buf(false, true)

			callback({ buf = buf })

			assert.are.equal("archive", vim.b[buf].journal_status)

			vim.api.nvim_buf_delete(buf, { force = true })
			buf_name_stub:revert()
			strftime_stub:revert()
		end)
	end)
end)
