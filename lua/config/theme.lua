-- Colourscheme switching and persistence.
--
-- The families below exist because the themes split light and dark two
-- different ways, and one toggle has to cope with both:
--
--   * tokyonight and cyberdream read `vim.o.background`, so flipping that and
--     re-applying the same name is enough.
--   * catppuccin, rose-pine and kanagawa expose their variants as separate
--     colourscheme NAMES, so switching means changing the name.
--
-- tokyonight is the default: the web guide's palette was hand-derived from it,
-- so the editor and the page match.

local M = {}

---@class ThemeFamily
---@field dark string
---@field light string
---@field plugin string|nil       lazy plugin to load before applying
---@field by_background boolean|nil  true when the scheme reads vim.o.background

---@type ThemeFamily[]
M.families = {
  -- graphite ships in this repo (colors/graphite.lua), so it needs no plugin.
  { dark = "graphite",   light = "graphite",   by_background = true },
  { dark = "tokyonight", light = "tokyonight", plugin = "tokyonight.nvim", by_background = true },
}

M.default = "graphite"

-- What we last applied. `vim.g.colors_name` cannot be trusted for this: apply
-- "tokyonight" and it reports "tokyonight-night"; apply "rose-pine-main" and it
-- reports "rose-pine". Matching the family on that silently fell through to the
-- fallback branch, so tokyonight's toggle did nothing.
M.current = nil

local STATE = vim.fn.stdpath("data") .. "/theme"
local LEGACY = vim.fn.stdpath("data") .. "/theme-background"

--- Read the saved preference. Understands the older single-line file that only
--- held light/dark, so an existing choice is not silently discarded.
---@return string|nil colorscheme, string|nil background
function M.load_saved()
  if vim.fn.filereadable(STATE) == 1 then
    local lines = vim.fn.readfile(STATE)
    local scheme = lines[1] and vim.trim(lines[1]) or nil
    local bg = lines[2] and vim.trim(lines[2]) or nil
    if scheme == "" then scheme = nil end
    if bg ~= "dark" and bg ~= "light" then bg = nil end
    return scheme, bg
  end

  if vim.fn.filereadable(LEGACY) == 1 then
    local bg = vim.trim(vim.fn.readfile(LEGACY)[1] or "")
    if bg == "dark" or bg == "light" then return nil, bg end
  end

  return nil, nil
end

local function save(scheme, bg)
  pcall(vim.fn.writefile, { scheme, bg }, STATE)
end

---@param name string
---@return ThemeFamily|nil family, string|nil which  "dark" or "light"
function M.family_of(name)
  for _, f in ipairs(M.families) do
    if f.dark == name then return f, "dark" end
    if f.light == name then return f, "light" end
  end
  return nil, nil
end

-- Lazy plugins are not loaded by `:colorscheme` alone -- the colours/ file is
-- not on the runtime path until the plugin loads -- so load it explicitly.
local function ensure_loaded(plugin)
  if not plugin then return end
  local ok, lazy = pcall(require, "lazy")
  if ok then pcall(lazy.load, { plugins = { plugin } }) end
end

--- Apply a colourscheme and remember it.
---@param name string
---@param bg string|nil  "dark" or "light"; inferred from the family when omitted
function M.apply(name, bg)
  local family, which = M.family_of(name)
  bg = bg or which or vim.o.background

  ensure_loaded(family and family.plugin)
  vim.o.background = bg

  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify("Could not apply " .. name .. ":\n" .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  M.current = name
  save(name, bg)
  return true
end

--- Restore whatever was saved, falling back to tokyonight dark.
function M.restore()
  local scheme, bg = M.load_saved()
  M.apply(scheme or M.default, bg or "dark")
end

--- Flip between the light and dark side of the current family.
function M.toggle_background()
  local current = M.current or vim.g.colors_name or M.default
  local family, which = M.family_of(current)

  if not family then
    -- Not one of ours (a Neovim built-in, say). Flip background and hope the
    -- scheme respects it; say so if it does not.
    local target = vim.o.background == "dark" and "light" or "dark"
    vim.o.background = target
    pcall(vim.cmd.colorscheme, current)
    vim.notify(current .. " is not in the theme list; set background=" .. target)
    return
  end

  if family.by_background then
    local target = vim.o.background == "dark" and "light" or "dark"
    M.apply(current, target)
    vim.notify(current .. " -> " .. target)
  else
    local target = which == "dark" and family.light or family.dark
    M.apply(target)
    vim.notify(target)
  end
end

--- Every variant this config knows about, for a picker.
function M.names()
  local seen, out = {}, {}
  for _, f in ipairs(M.families) do
    for _, n in ipairs({ f.dark, f.light }) do
      if not seen[n] then
        seen[n] = true
        table.insert(out, n)
      end
    end
  end
  return out
end

return M
