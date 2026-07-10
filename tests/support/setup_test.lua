local jjournal = require("jjournal")
local stub = require("luassert.stub")

-- Configures jjournal against a virtual journal path, installs any requested
-- stubs, runs `test_fn`, then always reverts the stubs and restores config
-- -- whether `test_fn` returns normally or raises an error (e.g. a failed
-- assertion). Mocks are installed *before* setup() runs, so they also
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
-- `config` overrides the base_dir/file_path/use_default_mappings passed to
-- setup(). Those three are always explicitly (re-)passed here so every test
-- starts from the same known fixture values, regardless of what a previous
-- test configured.
--
-- jjournal.setup() merges into the *existing* jjournal.config rather than
-- replacing it, and jjournal.config is a module-level table that persists
-- across tests -- so on its own, merging would let any key a test sets leak
-- into every later test that doesn't override it (not just the three
-- listed above; any current or future config key). To keep tests isolated
-- from each other regardless, this snapshots jjournal.config before
-- (re-)running setup(), and restores that exact snapshot once `test_fn`
-- finishes -- undoing this test's config changes in full, not just the
-- keys we happened to think to reset.
--
-- Cleanup previously ran via a `cleanup` function this returned, which a
-- test had to remember to call -- and skipped entirely if the test threw
-- before reaching it, leaking stubs/config into every test that ran after.
-- Taking the test body as `test_fn` instead makes cleanup unconditional: it
-- always runs, even when `test_fn` errors, and the error is then re-raised
-- so busted still reports the failure.
local function setup_test(mocks, test_fn)
	mocks = mocks or {}
	local active_stubs = {}
	local previous_config = vim.deepcopy(jjournal.config)

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
		base_dir = "/virtual/test/journal/path/",
		file_path = "%Y-%m-%d.md",
		use_default_mappings = false,
	}, mocks.config or {}))

	local ok, err = pcall(test_fn)

	jjournal.config = previous_config
	for _, s in ipairs(active_stubs) do
		s:revert()
	end

	if not ok then error(err, 0) end
end

return setup_test
