-- Chronological navigation math: figuring out where step/skip should land.
-- Everything here is private except M.step and M.skip, the two things
-- jjournal/init.lua actually needs. Neither depends on "today" at all --
-- each is a consistent, direction-only operation regardless of where
-- today happens to fall.
local path = require "jjournal.path"

local M = {}

---Pinpoints the current YYYY-MM-DD anchor string for a step/skip
---navigation, from the current buffer's jjournal_date -- the buffer-local
---var register_autocmds' tagging autocmd sets on every buffer jjournal
---manages (see init.lua). Falls back to today when unset, which only
---actually triggers for a caller invoking resolve_date/execute directly
---from a buffer jjournal never tagged (e.g. a custom global mapping with
---use_default_mappings = false, invoked from outside the journal path) --
---the default step/skip mappings are buffer_local, so they can't reach
---this function from an untagged buffer to begin with.
---@return string
local function current_anchor_date()
  return vim.b[0].jjournal_date or vim.fn.strftime "%F"
end

---The set of dates with journal files physically written to the storage
---directory, recursing into subdirectories so nested file_paths are
---discovered. Each match contributes its bare YYYY-MM-DD date, not its
---literal filename, since the filename may carry any prefix/suffix/extension.
---@param base_dir string
---@return table<string, true>
local function dates_from_disk(base_dir)
  local date_set = {}
  local matches = vim.fn.glob(path.normalize_base_dir(base_dir) .. "**/*", false, true)
  for _, full_path in ipairs(matches) do
    local date = path.extract_date_from_filename(vim.fn.fnamemodify(full_path, ":t"))
    if date then date_set[date] = true end
  end
  return date_set
end

---The set of dates with journal buffers currently held in active virtual
---memory.
---@return table<string, true>
local function dates_from_buffers()
  local date_set = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local date = path.extract_date_from_filename(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t"))
      if date then date_set[date] = true end
    end
  end
  return date_set
end

---Flattens a unique date set into an ordered, chronological array.
---@param date_set table<string, true>
---@return string[]
local function flatten_and_sort_dates(date_set)
  local dates = {}
  for date, _ in pairs(date_set) do
    table.insert(dates, date)
  end
  table.sort(dates)
  return dates
end

---Every available date, from both disk and open buffers, as one sorted
---array.
---@param base_dir string
---@return string[]
local function all_available_dates(base_dir)
  return flatten_and_sort_dates(vim.tbl_extend("force", dates_from_disk(base_dir), dates_from_buffers()))
end

---The destination index in a sorted date array for a skip-search in
---`direction` from `current`, `count` entries out (default 1, i.e. the
---nearest one). May return an out-of-range index (e.g. requesting the 5th
---entry when only 2 exist) -- M.skip indexes the array with it directly
---and relies on Lua's out-of-bounds table reads returning nil, rather than
---bounds-checking here too.
---@param dates string[]
---@param current string
---@param direction integer
---@param count integer|nil
---@return integer|nil
local function target_index(dates, current, direction, count)
  local index = nil
  for i, date in ipairs(dates) do
    if date >= current then
      if direction > 0 then
        index = (date == current) and i + 1 or i
      else
        index = i - 1
      end
      break
    end
  end

  if not index and direction < 0 then index = #dates end
  if not index then return nil end

  return index + direction * ((count or 1) - 1)
end

---Shifts a YYYY-MM-DD date string by `days` (may be negative). Anchored at
---noon rather than midnight so a +/- 86400 second shift can't land on the
---wrong calendar day across a DST transition (a 23- or 25-hour day).
---@param date_str string
---@param days integer
---@return string
local function shift_date(date_str, days)
  local year, month, day = date_str:match "(%d%d%d%d)%-(%d%d)%-(%d%d)"
  local time = os.time { year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 12 }
  return os.date("%Y-%m-%d", time + days * 86400)
end

---Shifts `count` calendar days (default 1) in `direction` from wherever the
---current buffer is anchored (see current_anchor_date), regardless of
---whether the result lands before or after today. open_date's own
---auto-creation opens it whether or not a file exists for it yet. Unlike
---M.skip, this never touches disk/buffer state, so it takes no base_dir.
---@param direction integer
---@param count integer|nil
---@return string
function M.step(direction, count)
  local current = current_anchor_date()
  local days = count or 1
  return shift_date(current, direction > 0 and days or -days)
end

---Jumps to the `count`-th existing entry (default 1, i.e. the nearest one;
---on disk or in an open buffer) in `direction` from wherever the current
---buffer is anchored, regardless of whether the result lands before or
---after today. Returns nil if there is no such entry in that direction
---(including when fewer than `count` entries exist).
---@param base_dir string
---@param direction integer
---@param count integer|nil
---@return string|nil
function M.skip(base_dir, direction, count)
  local current = current_anchor_date()
  local dates = all_available_dates(base_dir)
  local index = target_index(dates, current, direction, count)

  return dates[index]
end

return M
