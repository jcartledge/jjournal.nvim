local jjournal = require("jjournal")
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

describe("Journal Engine Chronological Timeline", function()
	it("1. should accurately resolve 'today' target coordinates", function()
		setup_test()
		local expected_today = vim.fn.strftime("%F")

		jjournal.resolve_date("today", function(resolved_date)
			assert.are.equal(expected_today, resolved_date)
		end)
	end)

	it("2. should calculate correct chronological stepping across empty spaces", function()
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

	it("3. should intercept and prioritize virtual unwritten buffers over disk storage", function()
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

	it("4. should handle the timeline horizon edge gracefully when stepping past the end", function()
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
end)
