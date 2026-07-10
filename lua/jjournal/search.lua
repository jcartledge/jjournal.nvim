-- Pluggable backlog search: telescope if available, a builtin :vimgrep
-- fallback, or a user-supplied function. Nothing here reads jjournal's
-- config directly -- run() receives whatever it needs as parameters, so
-- there's no require cycle back to jjournal/init.lua.
local M = {}

---Whether telescope.nvim (specifically telescope.builtin) is installed.
---@return boolean
local function has_telescope()
  return pcall(require, "telescope.builtin")
end

---Prompts for a search term, then greps `base_dir` with Vim's builtin
---:vimgrep and opens the results in the quickfix list. Used directly when
---config.search = "builtin", and as the fallback when telescope isn't
---available.
---@param base_dir string
---@param extension string
local function builtin_search(base_dir, extension)
  vim.ui.input({ prompt = "Search journal for: " }, function(term)
    if not term or term == "" then return end

    local pattern = vim.fn.escape(term, "/\\")
    vim.cmd(string.format("vimgrep /%s/gj %s**/*%s", pattern, base_dir, extension))
    vim.cmd "copen"
  end)
end

---@type table<string, fun(base_dir: string, extension: string)>
M.providers = {
  telescope = function(base_dir)
    require("telescope.builtin").live_grep {
      search_dirs = { base_dir },
      prompt_title = "Search Journal Backlog",
    }
  end,
  builtin = builtin_search,
}

---Runs the configured search provider against `base_dir`/`extension`.
---`choice` defaults to "auto" (telescope if available, otherwise the
---builtin vimgrep-based search). It can also be "telescope" or "builtin"
---explicitly, or a function(base_dir) for any other picker.
---@param choice string|fun(base_dir: string)|nil
---@param base_dir string
---@param extension string
function M.run(choice, base_dir, extension)
  if type(choice) == "function" then
    choice(base_dir)
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

  local provider = M.providers[choice]
  if not provider then
    vim.notify("jjournal: unknown search provider '" .. tostring(choice) .. "'", vim.log.levels.WARN)
    return
  end

  provider(base_dir, extension)
end

return M
