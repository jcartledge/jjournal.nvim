-- lua/user/journal.lua
local M = {}

M.config = {
  path = vim.fn.expand "~/notes/journals/",
  use_default_mappings = true,
  search = "auto",
}

local function get_path()
  local path = M.config.path
  return path:sub(-1) == "/" and path or path .. "/"
end

-- ========================================================================
-- PRIVATE CHRONOLOGICAL HELPERS (Decomposed Atom 1 sub-components)
-- ========================================================================

-- Pinpoints the current YYYY-MM-DD anchor string based on the active window context.
-- Only trusts the buffer's own name if it actually lives inside the configured
-- journal path -- an unrelated date-named file elsewhere shouldn't be treated
-- as the navigation anchor.
local function get_current_date_coordinate()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local current = vim.fn.expand "%:t"
  if current == "" then current = vim.fn.fnamemodify(buf_name, ":t") end

  local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
  local journal_dir = vim.fn.fnamemodify(get_path(), ":p"):gsub("/$", "")

  if buf_dir ~= journal_dir or not current:match "%d%d%d%d%-%d%d%-%d%d" then
    return vim.fn.strftime "%F" .. ".md"
  end
  return current
end

-- Collects all valid journal files physically written to the storage directory
local function get_dates_from_disk(date_set)
  local folder = get_path()
  local disk_files = vim.fn.readdir(folder)
  for _, filename in ipairs(disk_files) do
    if filename:match "^%d%d%d%d%-%d%d%-%d%d%.md$" then date_set[filename] = true end
  end
end

-- Collects all valid journal buffers currently held in active virtual memory
local function get_dates_from_buffers(date_set)
  local active_buffers = vim.api.nvim_list_bufs()
  for _, buf in ipairs(active_buffers) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      local filename = vim.fn.fnamemodify(buf_name, ":t")
      if filename:match "^%d%d%d%d%-%d%d%-%d%d%.md$" then date_set[filename] = true end
    end
  end
end

-- Flattens a unique dictionary set into an ordered, chronological array
local function flatten_and_sort_dates(date_set)
  local files = {}
  for filename, _ in pairs(date_set) do
    table.insert(files, filename)
  end
  table.sort(files)
  return files
end

-- Aggregates available timeline coordinates from both physical and virtual realms
local function get_all_available_dates()
  local date_set = {}

  get_dates_from_disk(date_set)
  get_dates_from_buffers(date_set)

  return flatten_and_sort_dates(date_set)
end

-- Calculates the correct destination index in our sorted timeline list
local function calculate_target_index(files, current, direction)
  local target_index = nil
  for i, filename in ipairs(files) do
    if filename >= current then
      if direction > 0 then
        target_index = (filename == current) and i + 1 or i
      else
        target_index = i - 1
      end
      break
    end
  end

  if not target_index and direction < 0 then target_index = #files end
  return target_index
end

-- The Main Navigation Orchestrator
local function get_nav_date(direction)
  local current = get_current_date_coordinate()
  local files = get_all_available_dates()
  local target_index = calculate_target_index(files, current, direction)

  local target_file = files[target_index]
  return target_file and target_file:gsub("%.md$", "") or nil
end

-- ========================================================================
-- 1. ATOM 1: THE DATE RESOLVERS (Pure Data Generation)
-- ========================================================================

-- Pluggable UI Strategy: Simple String Prompt Adapter
M.prompt_for_date = function(callback)
  local today_str = vim.fn.strftime "%F"
  vim.ui.input({ prompt = "Go to journal date: ", default = today_str }, function(input)
    if input and input ~= "" then callback(input) end
  end)
end

-- The Router Atom: Resolves a strategy type into a raw YYYY-MM-DD string
M.resolve_date = function(target, callback)
  if target == "today" then
    callback(vim.fn.strftime "%F")
  elseif target == "prev" then
    callback(get_nav_date(-1))
  elseif target == "next" then
    callback(get_nav_date(1))
  elseif target == "prompt" then
    M.prompt_for_date(callback)
  end
end

-- ========================================================================
-- 2. ATOM 2: THE ACTION OPENER (Pure File System Execution)
-- ========================================================================
M.open_date = function(date_str, cmd)
  if not date_str then
    vim.notify("Journal date could not be resolved", vim.log.levels.WARN)
    return
  end

  local full_path = get_path() .. date_str .. ".md"
  local dir = vim.fn.fnamemodify(full_path, ":h")
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

  vim.cmd(string.format("%s %s", cmd or "edit", full_path))
end

-- Global Search: pluggable search providers, selected via config.search.
local function has_telescope()
  return pcall(require, "telescope.builtin")
end

-- Prompts for a search term, then greps the configured journal path with
-- Vim's builtin :vimgrep and opens the results in the quickfix list. Used
-- directly when config.search = "builtin", and as the fallback when
-- telescope isn't available.
local function builtin_search(path)
  vim.ui.input({ prompt = "Search journal for: " }, function(term)
    if not term or term == "" then return end

    local pattern = vim.fn.escape(term, "/\\")
    vim.cmd(string.format("vimgrep /%s/gj %s**/*.md", pattern, path))
    vim.cmd "copen"
  end)
end

M.search_providers = {
  telescope = function(path)
    require("telescope.builtin").live_grep {
      search_dirs = { path },
      prompt_title = "Search Journal Backlog",
    }
  end,
  builtin = builtin_search,
}

-- config.search defaults to "auto" (telescope if available, otherwise the
-- builtin vimgrep-based search). It can also be "telescope" or "builtin"
-- explicitly, or a function(path) for any other picker.
M.search_backlog = function()
  local choice = M.config.search

  if type(choice) == "function" then
    choice(get_path())
    return
  end

  if choice == "auto" or choice == nil then
    choice = has_telescope() and "telescope" or "builtin"
  elseif choice == "telescope" and not has_telescope() then
    vim.notify(
      "jjournal: telescope.nvim not found; falling back to builtin search. "
        .. "Install telescope.nvim or set config.search = 'builtin' to silence this.",
      vim.log.levels.WARN
    )
    choice = "builtin"
  end

  local provider = M.search_providers[choice]
  if not provider then
    vim.notify("jjournal: unknown search provider '" .. tostring(choice) .. "'", vim.log.levels.WARN)
    return
  end

  provider(get_path())
end

-- ========================================================================
-- 3. THE UNIFIED EXECUTION PIPELINE
-- ========================================================================
M.execute = function(target, cmd)
  if target == "search" then
    M.search_backlog()
    return
  end

  M.resolve_date(target, function(resolved_date) M.open_date(resolved_date, cmd) end)
end

-- ========================================================================
-- 4. PRIVATE INITIALIZATION SUBSYSTEMS
-- ========================================================================
local function bind_mappings()
  if not M.config.use_default_mappings then return end

  for lhs, spec in pairs(M.mappings) do
    if spec ~= false then
      vim.keymap.set("n", lhs, function() M.execute(spec.target, spec.cmd) end, { desc = spec.desc, silent = true })
    end
  end
end

local function register_autocmds()
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("JournalEngineCore", { clear = true }),
    pattern = get_path() .. "*.md",
    callback = function(args)
      local current_buf = args.buf
      local current_path = vim.api.nvim_buf_get_name(current_buf)
      local today_path = get_path() .. vim.fn.strftime "%F" .. ".md"

      if vim.fn.fnamemodify(current_path, ":p") == vim.fn.fnamemodify(today_path, ":p") then
        vim.b[current_buf].journal_status = "today"
      else
        vim.b[current_buf].journal_status = "archive"
      end
    end,
  })
end

-- ========================================================================
-- 5. EXPOSED DEFAULT MAPPINGS & SETUP INTERFACE
-- ========================================================================
M.mappings = {
  ["gj"] = { target = "today", cmd = "edit", desc = "Go to today's journal" },
  ["gJ"] = { target = "today", cmd = "vsplit", desc = "Go to today's journal (split)" },
  ["[j"] = { target = "prev", cmd = "edit", desc = "Previous journal" },
  ["]j"] = { target = "next", cmd = "edit", desc = "Next journal" },
  ["[J"] = { target = "prev", cmd = "vsplit", desc = "Previous journal (split)" },
  ["]J"] = { target = "next", cmd = "vsplit", desc = "Next journal (split)" },
  ["<leader>fj"] = { target = "search", cmd = "grep", desc = "Search journal backlog (grep)" },

  ["<leader>jj"] = { target = "prompt", cmd = "edit", desc = "Jump to journal date" },
  ["<leader>jJ"] = { target = "prompt", cmd = "vsplit", desc = "Jump to journal date (split)" },
}

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  bind_mappings()
  register_autocmds()
end

return M
