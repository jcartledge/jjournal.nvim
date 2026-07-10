-- lua/user/journal.lua
local M = {}

M.config = {
  base_dir = vim.fn.expand "~/notes/journals/",
  file_path = "%Y/%m/%Y-%m-%d.md",
  use_default_mappings = true,
  search = "auto",
}

local function get_base_dir()
  local base_dir = M.config.base_dir
  return base_dir:sub(-1) == "/" and base_dir or base_dir .. "/"
end

-- Extracts the embedded YYYY-MM-DD date from anywhere within a filename,
-- so journal files may have any prefix, suffix, or extension around the
-- full date (e.g. "journal-2026-07-09.txt"), not just an exact
-- "YYYY-MM-DD.md" name.
local function extract_date_from_filename(filename)
  return filename:match "%d%d%d%d%-%d%d%-%d%d"
end

-- Returns the filename portion (segment after the last "/") of a file_path.
local function file_path_filename(file_path)
  return file_path:match "([^/]+)$" or file_path
end

-- Derives the extension (including the leading ".") from file_path's
-- filename portion, so recursive glob patterns and search stay scoped to
-- whatever extension the user's file_path actually uses, instead of a
-- hardcoded ".md".
local function file_path_extension(file_path)
  return file_path_filename(file_path):match "(%.[^.]+)$" or ""
end

-- Expands a file_path template against a resolved YYYY-MM-DD date string.
-- %D is shorthand for the full date and is expanded first (as a plain
-- substitution, not a placeholder-of-placeholders), then %Y/%m/%d are
-- substituted individually so they may still be used on their own
-- (e.g. for directory nesting) alongside %D.
local function expand_file_path(file_path, date_str)
  local year, month, day = date_str:match "(%d%d%d%d)%-(%d%d)%-(%d%d)"
  return (file_path:gsub("%%D", date_str):gsub("%%Y", year):gsub("%%m", month):gsub("%%d", day))
end

-- ========================================================================
-- PRIVATE CHRONOLOGICAL HELPERS (Decomposed Atom 1 sub-components)
-- ========================================================================

-- Pinpoints the current YYYY-MM-DD anchor string based on the active window context.
-- Only trusts the buffer's own name if it actually lives inside (at or below)
-- the configured journal base_dir -- an unrelated date-named file elsewhere
-- shouldn't be treated as the navigation anchor.
local function get_current_date_coordinate()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local tail = vim.fn.expand "%:t"
  if tail == "" then tail = vim.fn.fnamemodify(buf_name, ":t") end

  local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
  local journal_dir = vim.fn.fnamemodify(get_base_dir(), ":p"):gsub("/$", "")
  local inside_journal_path = buf_dir == journal_dir or buf_dir:sub(1, #journal_dir + 1) == journal_dir .. "/"

  local date = inside_journal_path and extract_date_from_filename(tail)
  return date or vim.fn.strftime "%F"
end

-- Collects all valid journal files physically written to the storage
-- directory, recursing into subdirectories so nested file_paths are
-- discovered. Each match contributes its bare YYYY-MM-DD date, not its
-- literal filename, since the filename may carry any prefix/suffix/extension.
local function get_dates_from_disk(date_set)
  local matches = vim.fn.glob(get_base_dir() .. "**/*", false, true)
  for _, full_path in ipairs(matches) do
    local date = extract_date_from_filename(vim.fn.fnamemodify(full_path, ":t"))
    if date then date_set[date] = true end
  end
end

-- Collects all valid journal buffers currently held in active virtual memory
local function get_dates_from_buffers(date_set)
  local active_buffers = vim.api.nvim_list_bufs()
  for _, buf in ipairs(active_buffers) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      local date = extract_date_from_filename(vim.fn.fnamemodify(buf_name, ":t"))
      if date then date_set[date] = true end
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

-- Shifts a YYYY-MM-DD date string by `days` (may be negative). Anchored at
-- noon rather than midnight so a +/- 86400 second shift can't land on the
-- wrong calendar day across a DST transition (a 23- or 25-hour day).
local function shift_date(date_str, days)
  local year, month, day = date_str:match "(%d%d%d%d)%-(%d%d)%-(%d%d)"
  local time = os.time { year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 12 }
  return os.date("%Y-%m-%d", time + days * 86400)
end

-- The Main Navigation Orchestrator.
--
-- Shifting the current date by one day in the requested direction is the
-- candidate destination. If that candidate is today or later, it's used
-- directly -- stepping exactly one day at a time into today/the future, and
-- opened whether or not a file exists for it yet (open_date already
-- auto-creates missing directories). Only when the candidate is still
-- before today does this fall back to skip-searching for the nearest
-- existing entry in that direction, preserving history-browsing behavior.
local function get_nav_date(direction)
  local current = get_current_date_coordinate()
  local today = vim.fn.strftime "%F"
  local candidate = shift_date(current, direction > 0 and 1 or -1)

  if candidate >= today then return candidate end

  local files = get_all_available_dates()
  local target_index = calculate_target_index(files, current, direction)

  return files[target_index]
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

-- Resolves a YYYY-MM-DD date string to its full file path, per
-- config.base_dir and config.file_path. Used uniformly by open_date and by
-- the today/archive autocmd, so both agree on where a given date lives.
M.resolve_path = function(date_str)
  return get_base_dir() .. expand_file_path(M.config.file_path, date_str)
end

-- ========================================================================
-- 2. ATOM 2: THE ACTION OPENER (Pure File System Execution)
-- ========================================================================
M.open_date = function(date_str, cmd)
  if not date_str then
    vim.notify("Journal date could not be resolved", vim.log.levels.WARN)
    return
  end

  local full_path = M.resolve_path(date_str)
  local dir = vim.fn.fnamemodify(full_path, ":h")
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

  vim.cmd(string.format("%s %s", cmd or "edit", full_path))
end

-- Global Search: pluggable search providers, selected via config.search.
local function has_telescope()
  return pcall(require, "telescope.builtin")
end

-- Prompts for a search term, then greps the configured journal base_dir with
-- Vim's builtin :vimgrep and opens the results in the quickfix list. Used
-- directly when config.search = "builtin", and as the fallback when
-- telescope isn't available.
local function builtin_search(base_dir)
  vim.ui.input({ prompt = "Search journal for: " }, function(term)
    if not term or term == "" then return end

    local pattern = vim.fn.escape(term, "/\\")
    local ext = file_path_extension(M.config.file_path)
    vim.cmd(string.format("vimgrep /%s/gj %s**/*%s", pattern, base_dir, ext))
    vim.cmd "copen"
  end)
end

M.search_providers = {
  telescope = function(base_dir)
    require("telescope.builtin").live_grep {
      search_dirs = { base_dir },
      prompt_title = "Search Journal Backlog",
    }
  end,
  builtin = builtin_search,
}

-- config.search defaults to "auto" (telescope if available, otherwise the
-- builtin vimgrep-based search). It can also be "telescope" or "builtin"
-- explicitly, or a function(base_dir) for any other picker.
M.search_backlog = function()
  local choice = M.config.search

  if type(choice) == "function" then
    choice(get_base_dir())
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

  provider(get_base_dir())
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
    pattern = get_base_dir() .. "**/*" .. file_path_extension(M.config.file_path),
    callback = function(args)
      local current_buf = args.buf
      local current_path = vim.api.nvim_buf_get_name(current_buf)
      local today_path = M.resolve_path(vim.fn.strftime "%F")

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

-- Navigation identifies a file's date by extracting a YYYY-MM-DD substring
-- from its filename alone (see extract_date_from_filename), so the
-- filename portion of file_path must guarantee one is recoverable: either
-- the composite %D token, or the literal %Y-%m-%d sequence written out
-- (any prefix, suffix, or extension around it is fine).
local function validate_file_path(file_path)
  local filename = file_path_filename(file_path)
  local has_full_date = filename:find("%D", 1, true) or filename:find("%Y-%m-%d", 1, true)
  if not has_full_date then
    error(
      "jjournal: config.file_path's filename must contain '%D' or the literal '%Y-%m-%d' "
        .. "so every file stays uniquely and recoverably dated by its filename alone; got: "
        .. file_path,
      0
    )
  end
end

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  validate_file_path(M.config.file_path)

  bind_mappings()
  register_autocmds()
end

return M
