-- Colourscheme switching and persistence.
--
-- All three themes read `vim.o.background`, so <leader>ut flips that and
-- re-applies the same name. The `by_background` field on a family is what says
-- so; it exists because the four themes dropped in f5f26fb (catppuccin,
-- rose-pine, kanagawa, cyberdream) exposed their light and dark variants as
-- separate colourscheme NAMES instead, and a future addition might again.
--
-- graphite is the default and ships in this repo (colors/graphite.lua).

local M = {}

---@class ThemeFamily
---@field dark string
---@field light string
---@field plugin string|nil       lazy plugin to load before applying
---@field by_background boolean|nil  true when the scheme reads vim.o.background

---@type ThemeFamily[]
-- All three ship in this repo (colors/*.lua + lua/scheme/palettes/), so none
-- needs a plugin loaded before it can be applied.
M.families = {
  { dark = "graphite",  light = "graphite",  by_background = true },
  { dark = "heather",   light = "heather",   by_background = true },
  { dark = "malachite", light = "malachite", by_background = true },
}

M.default = "graphite"

-- What we last applied. `vim.g.colors_name` cannot always be trusted for this:
-- plugin schemes rename themselves on load -- apply "tokyonight" and it reports
-- "tokyonight-night" -- and matching the family on that silently fell through
-- to the fallback branch, so the toggle did nothing. The in-repo schemes do not
-- do that, but the guard costs nothing and outlives them.
M.current = nil

local STATE = vim.fn.stdpath("data") .. "/theme"

--- Read the saved preference: colourscheme on line one, background on line two.
---@return string|nil colorscheme, string|nil background
function M.load_saved()
  if vim.fn.filereadable(STATE) == 0 then return nil, nil end

  local lines = vim.fn.readfile(STATE)
  local scheme = lines[1] and vim.trim(lines[1]) or nil
  local bg = lines[2] and vim.trim(lines[2]) or nil
  if scheme == "" then scheme = nil end
  if bg ~= "dark" and bg ~= "light" then bg = nil end
  return scheme, bg
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

--- Every scheme this config ships, for the picker.
---@return string[]
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

--- Pick a scheme, previewing each as you move.
---
--- Hand-rolled rather than telescope.builtin.colorscheme, which seeds its list
--- from `opts.colors` and then appends every colourscheme on the runtime path
--- anyway -- so the three that ship here would arrive buried in Neovim's stock
--- schemes. Same shape as the background picker in config/painting.lua.
function M.menu()
  local names = M.names()
  local restore_scheme = M.current or vim.g.colors_name or M.default
  local restore_bg = vim.o.background

  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.ui.select(names, { prompt = "Colourscheme" }, function(choice)
      if choice then M.apply(choice) end
    end)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_set = require("telescope.actions.set")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Colourscheme   (" .. restore_bg .. ")",
    finder = finders.new_table({
      results = names,
      entry_maker = function(name)
        return { value = name, display = name, ordinal = name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      -- Preview on move, without saving: moving over an entry should show it,
      -- not commit to it. Applying directly rather than through M.apply keeps
      -- the saved preference untouched until you actually choose.
      action_set.shift_selection:enhance({
        post = function()
          local entry = action_state.get_selected_entry()
          if entry then pcall(vim.cmd.colorscheme, entry.value) end
        end,
      })

      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then M.apply(entry.value, restore_bg) end
      end)

      -- Escaping puts back whatever was showing before, so browsing is free.
      actions.close:enhance({
        post = function()
          if M.current ~= restore_scheme then
            vim.o.background = restore_bg
            pcall(vim.cmd.colorscheme, restore_scheme)
          end
        end,
      })
      return true
    end,
  }):find()
end

return M
