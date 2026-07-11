-- Chronological navigation math: figuring out where step/skip should land.
-- Everything here is private except M.step and M.skip, the two things
-- jjournal/init.lua actually needs. Neither depends on "today" at all --
-- each is a consistent, direction-only operation regardless of where
-- today happens to fall.
local path = require "jjournal.path"

local M = {}

---Pinpoints the current YYYY-MM-DD anchor string based on the active window
---context. Only trusts the buffer's own name if it actually lives inside
---(at or below) the configured journal base_dir -- an unrelated date-named
---file elsewhere shouldn't be treated as the navigation anchor.
---@param base_dir string
---@return string
local function current_anchor_date(base_dir)
  local buf_name = vim.api.nvim_buf_get_name(0)
  local tail = vim.fn.expand "%:t"
  if tail == "" then tail = vim.fn.fnamemodify(buf_name, ":t") end

  local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
  local journal_dir = vim.fn.fnamemodify(path.normalize_base_dir(base_dir), ":p"):gsub("/$", "")
  local inside_journal_path = buf_dir == journal_dir or buf_dir:sub(1, #journal_dir + 1) == journal_dir .. "/"

  local date = inside_journal_path and path.extract_date_from_filename(tail)
  return date or vim.fn.strftime "%F"
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
---`direction` from `current`.
---@param dates string[]
---@param current string
---@param direction integer
---@return integer|nil
local function target_index(dates, current, direction)
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
  return index
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

---Shifts exactly one calendar day in `direction` from wherever the current
---buffer is anchored, regardless of whether the result lands before or
---after today. open_date's own auto-creation opens it whether or not a
---file exists for it yet.
---@param base_dir string
---@param direction integer
---@return string
function M.step(base_dir, direction)
  local current = current_anchor_date(base_dir)
  return shift_date(current, direction > 0 and 1 or -1)
end

---Jumps to the nearest existing entry (on disk or in an open buffer) in
---`direction` from wherever the current buffer is anchored, regardless of
---whether the result lands before or after today. Returns nil if there is
---no existing entry in that direction.
---@param base_dir string
---@param direction integer
---@return string|nil
function M.skip(base_dir, direction)
  local current = current_anchor_date(base_dir)
  local dates = all_available_dates(base_dir)
  local index = target_index(dates, current, direction)

  return dates[index]
end

return M
