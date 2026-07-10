local jjournal = require("jjournal")
local assert = require("luassert")
local setup_test = require("support.setup_test")
local busted = require("busted")
local describe, it = busted.describe, busted.it

-- setup_test itself isn't part of jjournal's public interface, so these
-- specs live separately from jjournal_spec.lua's one-describe-per-public-
-- function convention. They pin down setup_test's own cleanup contract:
-- config (and stubs) are always restored once test_fn finishes, whether it
-- returns normally or errors.
describe("support.setup_test", function()
	it("restores config after test_fn returns normally", function()
		local original_base_dir = jjournal.config.base_dir

		setup_test({ config = { base_dir = "/temporary/only/for/this/test" } }, function()
			assert.are.equal("/temporary/only/for/this/test", jjournal.config.base_dir)
		end)

		assert.are.equal(original_base_dir, jjournal.config.base_dir)
	end)

	it("still restores config when test_fn errors, and re-raises the error", function()
		local original_base_dir = jjournal.config.base_dir

		local ok, err = pcall(function()
			setup_test({ config = { base_dir = "/temporary/only/for/this/test" } }, function() error("boom") end)
		end)

		assert.is_false(ok)
		assert.matches("boom", err)
		assert.are.equal(original_base_dir, jjournal.config.base_dir)
	end)
end)
