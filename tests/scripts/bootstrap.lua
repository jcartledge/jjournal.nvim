-- Bootstrap Neovim's LuaJIT runtime for luarocks/busted test dependencies.
local uv = vim.uv or vim.loop
local root = vim.fn.getcwd()
local rocks_tree = root .. "/.rocks"

local function rocks_lua_version()
	for _, name in ipairs(vim.fn.readdir(rocks_tree .. "/share/lua")) do
		if name:match("^%d+%.%d+$") then
			return name
		end
	end
	return "5.1"
end

local lua_version = rocks_lua_version()

package.path = root
	.. "/lua/?.lua;"
	.. root
	.. "/lua/?/init.lua;"
	.. root
	.. "/tests/?.lua;"
	.. root
	.. "/tests/?/init.lua;"
	.. rocks_tree
	.. "/share/lua/"
	.. lua_version
	.. "/?.lua;"
	.. rocks_tree
	.. "/share/lua/"
	.. lua_version
	.. "/?/init.lua;"
	.. package.path

-- Do not add .rocks C paths: luarocks builds native modules for PUC Lua, but
-- tests run inside Neovim's LuaJIT. Shim the small native APIs busted needs.
local mode_map = {
	file = "file",
	dir = "directory",
	link = "link",
	socket = "socket",
	named_pipe = "named pipe",
	char = "character device",
	block = "block device",
	other = "other",
}

local function stat_to_attributes(stat)
	return {
		mode = mode_map[stat.type] or stat.type,
		size = stat.size,
		mtime = stat.mtime,
		atime = stat.atime,
		ctime = stat.ctime,
	}
end

package.preload["lfs"] = function()
	return {
		attributes = function(path, field)
			local stat = uv.fs_stat(path)
			if not stat then
				return nil
			end
			local attrs = stat_to_attributes(stat)
			if field then
				return attrs[field]
			end
			return attrs
		end,
		symlinkattributes = function(path, field)
			return package.loaded.lfs.attributes(path, field)
		end,
		currentdir = function()
			return uv.fs.cwd()
		end,
		chdir = function(path)
			local ok = pcall(vim.fn.chdir, path)
			return ok
		end,
		mkdir = function(path)
			return uv.fs_mkdir(path, 493)
		end,
		rmdir = function(path)
			return uv.fs_rmdir(path)
		end,
		dir = function(path)
			local handle, err = uv.fs_scandir(path)
			if not handle then
				error(err)
			end
			return function()
				local name = uv.fs_scandir_next(handle)
				if name then
					return name
				end
			end
		end,
	}
end

package.preload["system"] = function()
	return {
		gettime = function()
			return os.time()
		end,
		monotime = function()
			return uv.hrtime() / 1e9
		end,
		sleep = function(secs)
			uv.sleep(math.floor(secs * 1000 + 0.5))
			return true
		end,
	}
end

package.preload["term"] = function()
	return {
		isatty = function()
			return false
		end,
	}
end
