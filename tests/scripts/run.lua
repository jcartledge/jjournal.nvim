-- Entry point for `luarocks test --tree=.rocks`.
-- Runs busted inside Neovim so specs can use the vim API, with luacov coverage
-- in the same process (busted's built-in --coverage support).
dofile(vim.fn.getcwd() .. "/tests/scripts/bootstrap.lua")

require("busted.runner")({
	standalone = false,
	coverage = true,
	verbose = true,
	lpath = "lua/?.lua;lua/?/init.lua;tests/?.lua;tests/?/init.lua",
})

local luacov = require("luacov.runner")
if luacov.initialized then
	luacov.shutdown()
end
