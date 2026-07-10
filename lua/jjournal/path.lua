-- Pure file_path/base_dir template helpers -- no shared state, no Neovim
-- config lookups, so every value a function here needs is passed in
-- explicitly by the caller (jjournal/init.lua).
local M = {}

---Extracts the embedded YYYY-MM-DD date from anywhere within a filename, so
---journal files may have any prefix, suffix, or extension around the full
---date (e.g. "journal-2026-07-09.txt"), not just an exact "YYYY-MM-DD.md"
---name.
---@param filename string
---@return string|nil
function M.extract_date_from_filename(filename)
  return filename:match "%d%d%d%d%-%d%d%-%d%d"
end

---Returns the basename (segment after the last "/") of a file_path.
---@param file_path string
---@return string
function M.file_path_basename(file_path)
  return file_path:match "([^/]+)$" or file_path
end

---Derives the extension (including the leading ".") from file_path's
---basename, so recursive glob patterns and search stay scoped to whatever
---extension the user's file_path actually uses, instead of a hardcoded
---".md".
---@param file_path string
---@return string
function M.file_path_extension(file_path)
  return M.file_path_basename(file_path):match "(%.[^.]+)$" or ""
end

---Expands a file_path template against a resolved YYYY-MM-DD date string.
---%D is shorthand for the full date and is expanded first (as a plain
---substitution, not a placeholder-of-placeholders), then %Y/%m/%d are
---substituted individually so they may still be used on their own (e.g.
---for directory nesting) alongside %D.
---@param file_path string
---@param date_str string
---@return string
function M.expand_file_path(file_path, date_str)
  local year, month, day = date_str:match "(%d%d%d%d)%-(%d%d)%-(%d%d)"
  return (file_path:gsub("%%D", date_str):gsub("%%Y", year):gsub("%%m", month):gsub("%%d", day))
end

---Navigation identifies a file's date by extracting a YYYY-MM-DD substring
---from its filename alone (see extract_date_from_filename), so the
---filename portion of file_path must guarantee one is recoverable: either
---the composite %D token, or the literal %Y-%m-%d sequence written out
---(any prefix, suffix, or extension around it is fine). Raises an error if
---that isn't satisfiable.
---@param file_path string
function M.validate_file_path(file_path)
  local filename = M.file_path_basename(file_path)
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

---Guarantees a trailing slash on a configured base_dir value.
---@param base_dir string
---@return string
function M.normalize_base_dir(base_dir)
  return base_dir:sub(-1) == "/" and base_dir or base_dir .. "/"
end

return M
