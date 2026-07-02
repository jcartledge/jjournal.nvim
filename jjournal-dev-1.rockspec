rockspec_format = "3.0"
package = "jjournal"
version = "dev-1"
source = {
	url = "git+https://github.com/jcartledge/jjournal.nvim.git",
}
description = {
	summary = "A minimal daily journaling plugin for Neovim.",
	detailed = [[
      A streamlined, friction-free daily journaling framework built
      directly inside the Neovim editor ecosystem.
   ]],
	homepage = "https://github.com/jcartledge/jjournal.nvim",
	license = "MIT",
}
dependencies = {
	"lua >= 5.1",
}
test_dependencies = {
	"busted >= 2.2.0",
	"luacov >= 0.15.0",
	"luafilesystem",
}
test = {
	type = "command",
	command = "nvim --headless -l tests/run.lua",
}
build = {
	type = "builtin",
	modules = {},
}
