local jjournal = require("jjournal")
local stub = require("luassert.stub")

-- Configures jjournal against a virtual journal path, installs any requested
-- stubs, then calls jjournal.setup() and returns a cleanup function that
-- reverts them. Mocks are installed *before* setup() runs, so they also
-- observe setup()'s own side effects (keymap binding, autocmd registration).
--
-- This is the only place that should create stubs: tests should describe
-- *what* to mock via `mocks`, not call luassert.stub directly. See
-- CLAUDE.md's "Testing" section for the conventions this helper follows.
--
-- Supported mock namespaces:
--   fn       -> vim.fn
--   api      -> vim.api
--   ui       -> vim.ui
--   keymap   -> vim.keymap
--   vim      -> the vim global itself (e.g. vim.cmd, vim.notify)
--   jjournal -> this module (e.g. to stub jjournal.execute)
--   on       -> escape hatch for arbitrary tables, as a list of
--               { target, key, value } triples, e.g. a fake telescope module
-- A mock value may be a fixed return value or a function; luassert.stub
-- invokes it as the implementation when the value is callable.
--
-- `config` overrides the path/use_default_mappings passed to setup().
local function setup_test(mocks)
	mocks = mocks or {}
	local active_stubs = {}

	local function stub_namespace(target, entries)
		for key, value in pairs(entries or {}) do
			table.insert(active_stubs, stub(target, key, value))
		end
	end

	stub_namespace(vim.fn, mocks.fn)
	stub_namespace(vim.api, mocks.api)
	stub_namespace(vim.ui, mocks.ui)
	stub_namespace(vim.keymap, mocks.keymap)
	stub_namespace(vim, mocks.vim)
	stub_namespace(jjournal, mocks.jjournal)

	for _, entry in ipairs(mocks.on or {}) do
		table.insert(active_stubs, stub(entry[1], entry[2], entry[3]))
	end

	jjournal.setup(vim.tbl_extend("force", {
		path = "/virtual/test/journal/path/",
		use_default_mappings = false,
	}, mocks.config or {}))

	return function()
		for _, s in ipairs(active_stubs) do
			s:revert()
		end
	end
end

return setup_test
