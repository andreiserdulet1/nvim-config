-- Colourscheme persistence: Graphite, light or dark.
--
-- graphite ships in this repo (colors/graphite.lua) and reads
-- `vim.o.background`, so <leader>ut flips that and re-applies the same name.
-- The choice is remembered across restarts.

local M = {}

M.default = "graphite"

local STATE = vim.fn.stdpath("data") .. "/theme"

--- Read the saved preference: colourscheme on line one, background on line two.
--- The scheme line is kept for compatibility with the older multi-theme file;
--- anything other than graphite falls back to it.
---@return string scheme, string|nil background
function M.load_saved()
  if vim.fn.filereadable(STATE) == 0 then return M.default, nil end
  local lines = vim.fn.readfile(STATE)
  local bg = lines[2] and vim.trim(lines[2]) or nil
  if bg ~= "dark" and bg ~= "light" then bg = nil end
  return M.default, bg
end

--- Apply the colourscheme with the given background and remember it.
---@param name string
---@param bg string|nil  "dark" or "light"
function M.apply(name, bg)
  bg = bg or vim.o.background
  vim.o.background = bg
  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify("Could not apply " .. name .. ":\n" .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  pcall(vim.fn.writefile, { name, bg }, STATE)
  return true
end

--- Flip between light and dark.
function M.toggle_background()
  local target = vim.o.background == "dark" and "light" or "dark"
  M.apply(vim.g.colors_name or M.default, target)
  vim.notify("Theme: " .. target)
end

return M
