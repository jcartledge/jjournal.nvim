-- jjournal.nvim's logic is split across four files: path.lua (pure
-- file_path/base_dir template helpers), dates.lua (chronological
-- navigation math), search.lua (pluggable backlog search), and this file,
-- which owns config, the public API, and all Neovim wiring (mappings,
-- autocmds).
local path = require "jjournal.path"
local dates = require "jjournal.dates"
local search = require "jjournal.search"

local M = {}

M.config = {
  base_dir = vim.fn.expand "~/notes/journals/",
  file_path = "%Y/%m/%Y-%m-%d.md",
  use_default_mappings = true,
  search = "auto",
}

---Prompts for a date (defaulting to today) and invokes `callback` with the
---entered YYYY-MM-DD string. Does nothing if the prompt is cancelled.
---@param callback fun(date_str: string)
M.prompt_for_date = function(callback)
  local today_str = vim.fn.strftime "%F"
  vim.ui.input({ prompt = "Go to journal date: ", default = today_str }, function(input)
    if input and input ~= "" then callback(input) end
  end)
end

---Resolves `target` ("today", "prev", "next", or "prompt") to a
---`YYYY-MM-DD` string (or nil), passed to `callback`.
---@param target "today"|"prev"|"next"|"prompt"
---@param callback fun(date_str: string|nil)
M.resolve_date = function(target, callback)
  if target == "today" then
    callback(vim.fn.strftime "%F")
  elseif target == "prev" then
    callback(dates.get_nav_date(M.config.base_dir, -1))
  elseif target == "next" then
    callback(dates.get_nav_date(M.config.base_dir, 1))
  elseif target == "prompt" then
    M.prompt_for_date(callback)
  end
end

---Resolves a YYYY-MM-DD date string to its full file path, per
---config.base_dir and config.file_path. Used uniformly by open_date and by
---the today/archive autocmd, so both agree on where a given date lives.
---@param date_str string
---@return string
M.resolve_path = function(date_str)
  return path.normalize_base_dir(M.config.base_dir) .. path.expand_file_path(M.config.file_path, date_str)
end

---Opens the journal entry for `date_str` with the Ex command `cmd`
---(default "edit"), creating its parent directory if needed. Warns and
---does nothing if `date_str` is nil. If the entry doesn't already exist on
---disk, the opened buffer is flagged jjournal_preview, so it can be
---auto-wiped later if left unedited (see register_autocmds' BufWinLeave
---autocmd).
---@param date_str string|nil
---@param cmd string|nil
M.open_date = function(date_str, cmd)
  if not date_str then
    vim.notify("Journal date could not be resolved", vim.log.levels.WARN)
    return
  end

  local full_path = M.resolve_path(date_str)
  local dir = vim.fn.fnamemodify(full_path, ":h")
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

  local is_new_entry = vim.fn.filereadable(full_path) == 0
  vim.cmd(string.format("%s %s", cmd or "edit", full_path))
  if is_new_entry then vim.b[vim.fn.bufadd(full_path)].jjournal_preview = true end
end

---Runs the configured search provider. See config.search.
M.search_backlog = function()
  search.run(
    M.config.search,
    path.normalize_base_dir(M.config.base_dir),
    path.file_path_extension(M.config.file_path)
  )
end

---Runs one of the mapping actions directly: `target` is one of "today",
---"prev", "next", "prompt", or "search"; `cmd` is the Ex command used to
---open the result (e.g. "edit" or "vsplit"), ignored for "search".
---@param target "today"|"prev"|"next"|"prompt"|"search"
---@param cmd string|nil
M.execute = function(target, cmd)
  if target == "search" then
    M.search_backlog()
    return
  end

  M.resolve_date(target, function(resolved_date) M.open_date(resolved_date, cmd) end)
end

---Binds every entry in M.mappings in normal mode, unless
---use_default_mappings is false or the individual mapping was disabled.
local function bind_mappings()
  if not M.config.use_default_mappings then return end

  for lhs, spec in pairs(M.mappings) do
    if spec ~= false then
      vim.keymap.set("n", lhs, function() M.execute(spec.target, spec.cmd) end, { desc = spec.desc, silent = true })
    end
  end
end

---Registers the autocmds that keep journal buffers tagged with their
---today/archive status, and clean up unedited preview buffers. See each
---callback below for its own reasoning.
local function register_autocmds()
  -- Created once and reused for both autocmds below: nvim_create_augroup's
  -- clear = true wipes the group's existing contents, so calling it a
  -- second time here would erase the first autocmd we just registered.
  local group = vim.api.nvim_create_augroup("JournalEngineCore", { clear = true })
  local pattern = path.normalize_base_dir(M.config.base_dir) .. "**/*" .. path.file_path_extension(M.config.file_path)

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    pattern = pattern,
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

  -- Vim's own 'modified' state is enough to tell whether a preview buffer
  -- has been genuinely edited -- no separate flag-stripping autocmd needed.
  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    pattern = pattern,
    callback = function(args)
      local buf = args.buf
      if not vim.b[buf].jjournal_preview then return end

      -- Deferred to the next event-loop tick: wiping the buffer
      -- synchronously here -- while Vim is still mid-transition away from
      -- it, e.g. during the very :edit that's replacing it in this window
      -- -- raises E937 ("attempt to delete a buffer that is in use"), even
      -- though it's the buffer BufWinLeave says we're leaving. By the time
      -- this runs, that transition has completed, so win_findbuf below
      -- reflects reality directly: 0 genuinely means displayed nowhere,
      -- with no need to account for the leaving window still counting.
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        if vim.api.nvim_buf_get_option(buf, "modified") then return end
        if #vim.fn.win_findbuf(buf) > 0 then return end

        vim.cmd("bwipeout " .. buf)
      end)
    end,
  })
end

---@class JjournalMapping
---@field target "today"|"prev"|"next"|"prompt"|"search"
---@field cmd string
---@field desc string

---Default mappings bound when config.use_default_mappings is true. Set an
---entry to `false` before calling setup() to disable it individually.
---@type table<string, JjournalMapping|false>
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

---Merges `opts` into the current config and (re-)binds mappings and
---autocmds. See |jjournal-configuration| for available keys.
---@param opts table|nil
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  path.validate_file_path(M.config.file_path)

  bind_mappings()
  register_autocmds()
end

return M
