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

---Resolves `target` to a `YYYY-MM-DD` string (or nil), passed to
---`callback`. "step_prev"/"step_next" always shift `count` days (default 1)
---in that direction; "skip_prev"/"skip_next" always jump to the `count`-th
---existing entry (default 1, i.e. the nearest one) in that direction --
---neither depends on where today falls. `count` is ignored for "today" and
---"prompt", which have no meaningful notion of it.
---@param target "today"|"step_prev"|"step_next"|"skip_prev"|"skip_next"|"prompt"
---@param callback fun(date_str: string|nil)
---@param count integer|nil
M.resolve_date = function(target, callback, count)
  if target == "today" then
    callback(vim.fn.strftime "%F")
  elseif target == "step_prev" then
    callback(dates.step(M.config.base_dir, -1, count))
  elseif target == "step_next" then
    callback(dates.step(M.config.base_dir, 1, count))
  elseif target == "skip_prev" then
    callback(dates.skip(M.config.base_dir, -1, count))
  elseif target == "skip_next" then
    callback(dates.skip(M.config.base_dir, 1, count))
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
---does nothing if `date_str` is nil. Whether the opened buffer later gets
---auto-wiped if left unedited is decided entirely by register_autocmds'
---TextChanged/BufWinLeave autocmds, not here -- every journal buffer is
---eligible, regardless of whether the file existed on disk already.
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

  vim.cmd(string.format("%s %s", cmd or "edit", full_path))
end

---Runs the configured search provider. See config.search.
M.search_backlog = function()
  search.run(
    M.config.search,
    path.normalize_base_dir(M.config.base_dir),
    path.file_path_extension(M.config.file_path)
  )
end

---Marks the current buffer as pinned, exempting it from the
---TextChanged/BufWinLeave auto-cleanup (see register_autocmds) regardless
---of whether it's ever edited. One-way: there's no unpin -- close the
---buffer yourself (:bdelete/:bwipeout) if you no longer want it kept.
M.pin_buffer = function()
  vim.b[0].jjournal_pinned = true
end

---Runs one of the mapping actions directly: `target` is one of "today",
---"step_prev", "step_next", "skip_prev", "skip_next", "prompt", "pin", or
---"search"; `cmd` is the Ex command used to open the result (e.g. "edit"
---or "vsplit"), ignored for "pin"/"search". `count` is forwarded to
---resolve_date; see its docstring for what it means per target.
---@param target "today"|"step_prev"|"step_next"|"skip_prev"|"skip_next"|"prompt"|"pin"|"search"
---@param cmd string|nil
---@param count integer|nil
M.execute = function(target, cmd, count)
  if target == "search" then
    M.search_backlog()
    return
  end

  if target == "pin" then
    M.pin_buffer()
    return
  end

  M.resolve_date(target, function(resolved_date) M.open_date(resolved_date, cmd) end, count)
end

---Binds every non-buffer_local entry in M.mappings in normal mode, unless
---use_default_mappings is false or the individual mapping was disabled.
---Forwards vim.v.count1 as execute()'s count -- targets that don't use a
---count (today/prompt/search/pin) simply ignore it. Buffer-local entries
---(see JjournalMapping) are bound separately, per matching buffer -- see
---bind_buffer_local_mappings.
local function bind_mappings()
  if not M.config.use_default_mappings then return end

  for lhs, spec in pairs(M.mappings) do
    if spec ~= false and not spec.buffer_local then
      vim.keymap.set(
        "n",
        lhs,
        function() M.execute(spec.target, spec.cmd, vim.v.count1) end,
        { desc = spec.desc, silent = true }
      )
    end
  end
end

---Binds every buffer_local entry in M.mappings to `buf` specifically,
---unless use_default_mappings is false or the individual mapping was
---disabled. Step, skip, and pin only mean something for a buffer jjournal
---actually manages, so unlike the global mappings in bind_mappings, these
---are called per-buffer from the BufReadPost/BufNewFile autocmd rather than
---once at setup() -- pressing one of these keys anywhere else is simply not
---mapped at all, rather than silently acting on some unrelated buffer.
---@param buf integer
local function bind_buffer_local_mappings(buf)
  if not M.config.use_default_mappings then return end

  for lhs, spec in pairs(M.mappings) do
    if spec ~= false and spec.buffer_local then
      vim.keymap.set(
        "n",
        lhs,
        function() M.execute(spec.target, spec.cmd, vim.v.count1) end,
        { desc = spec.desc, silent = true, buffer = buf }
      )
    end
  end
end

---Registers the autocmds that keep journal buffers tagged with their
---today/archive status and buffer-local mappings bound, mark a buffer
---pinned the moment it's edited, and clean up unpinned buffers once left.
---See each callback below for its own reasoning.
local function register_autocmds()
  -- Created once and reused for all three autocmds below: nvim_create_augroup's
  -- clear = true wipes the group's existing contents, so calling it a
  -- second time here would erase the ones we just registered.
  local group = vim.api.nvim_create_augroup("JournalEngineCore", { clear = true })
  -- "**" .. ext (not "**/*" .. ext): autocmd-pattern's ** requires at least
  -- one subdirectory between base_dir and the filename to match, so the
  -- "/*" variant silently never matches a flat (non-nested) file_path
  -- layout with zero subdirectories. "**" alone matches both flat and
  -- nested paths correctly.
  local pattern = path.normalize_base_dir(M.config.base_dir) .. "**" .. path.file_path_extension(M.config.file_path)

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

      bind_buffer_local_mappings(current_buf)
    end,
  })

  -- Editing is a permanent signal for this buffer's lifetime, not a live
  -- read of Vim's own 'modified' state at cleanup time: 'modified' resets
  -- to false on :w (or a full undo back to the save point), which would
  -- otherwise make a buffer someone genuinely wrote in and saved look
  -- indistinguishable from one that was never touched.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    pattern = pattern,
    callback = function(args) vim.b[args.buf].jjournal_pinned = true end,
  })

  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    pattern = pattern,
    callback = function(args)
      local buf = args.buf
      if vim.b[buf].jjournal_pinned then return end

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
        if #vim.fn.win_findbuf(buf) > 0 then return end

        vim.cmd("bwipeout " .. buf)
      end)
    end,
  })
end

---@class JjournalMapping
---@field target "today"|"step_prev"|"step_next"|"skip_prev"|"skip_next"|"prompt"|"pin"|"search"
---@field desc string
---@field buffer_local boolean|nil Bound only within buffers jjournal manages (see bind_buffer_local_mappings), rather than globally. Omit/false for the default, global binding.

---Default mappings bound when config.use_default_mappings is true. Set an
---entry to `false` before calling setup() to disable it individually. None
---of these pass a cmd to execute() -- open_date's own "edit" default
---applies uniformly, since there's no split variant to select between.
---@type table<string, JjournalMapping|false>
M.mappings = {
  ["gj"] = { target = "today", desc = "Go to today's journal" },
  ["[jj"] = { target = "step_prev", desc = "Step to previous day", buffer_local = true },
  ["]jj"] = { target = "step_next", desc = "Step to next day", buffer_local = true },
  ["[j"] = { target = "skip_prev", desc = "Skip to previous entry", buffer_local = true },
  ["]j"] = { target = "skip_next", desc = "Skip to next entry", buffer_local = true },
  ["<leader>fj"] = { target = "search", desc = "Search journal backlog (grep)" },

  ["<leader>jj"] = { target = "prompt", desc = "Jump to journal date" },
  ["<leader>jp"] = { target = "pin", desc = "Pin the current journal buffer", buffer_local = true },
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
