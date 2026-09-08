-- Malachite: cool charcoal, with a single green carrying the accent.
--
-- Built from five colours:
--
--   #272D2D  charcoal  the dark ground
--   #A39BA8  mauve     comments
--   #B8C5D6  steel     secondary text
--   #EDF5FC  snow      the light ground, and the dark variant's body text
--   #23CE6B  green     the signature accent
--
-- Unusually for a palette this size, four of the five land on their intended
-- role as given, with no adjustment: on #272D2D the mauve measures 5.21:1, the
-- steel 8.00:1, the snow 12.72:1 and the green 6.74:1. Only the derived
-- shades -- and the whole light variant -- needed deriving.
--
-- Three source hues have to cover six syntax roles, so pairs share a hue and
-- separate by lightness: green carries functions and, paler, types; steel
-- carries strings and, deeper and bluer, numbers; mauve carries keywords.
-- Graphite does the same thing with its two warm tones.
--
-- Ratios are measured and recorded. Line numbers sit near 2.5:1 on purpose.

local M = {}

M.dark = {
  ground    = "#272D2D", -- the charcoal, as given
  surface   = "#313839",
  raised    = "#3a4143",
  selection = "#4a5156",
  border    = "#586166",

  text      = "#EDF5FC", -- 12.72:1  the snow, as given
  dim       = "#B8C5D6", --  8.00:1  the steel, as given
  comment   = "#A39BA8", --  5.21:1  the mauve, as given -- it already clears 4.5
  gutter    = "#6e6474", --  2.49:1  mauve, darkened; recessive on purpose

  -- A painting lifts the ground, which costs comments most of their margin.
  -- Measured against #414646, the brightest the painting may reach.
  comment_on_painting = "#b6b0ba", -- 4.53:1 against #414646

  amber     = "#23CE6B", --  6.74:1  the green, exactly as given -- functions
  clay      = "#cda7c3", --  6.61:1  mauve, lifted -- keywords
  sage      = "#7fd0a8", --  7.66:1  green softened toward steel -- strings
  slate     = "#92b0d4", --  6.26:1  steel, deepened and bluer -- numbers
  ochre     = "#93e3bb", --  9.30:1  green, palest step -- types
  rose      = "#e98896", --  5.62:1  errors

  add_bg    = "#22352c",
  add_fg    = "#23CE6B",
  change_bg = "#2f3540",
  change_fg = "#92b0d4",
  delete_bg = "#3a2a2e",
  delete_fg = "#e98896",
}

M.light = {
  ground    = "#EDF5FC", -- the snow, as given
  surface   = "#ffffff",
  raised    = "#dde7f1",
  selection = "#d0dbe7",
  border    = "#b6bdc2",

  text      = "#272D2D", -- 12.72:1  the charcoal, as given
  dim       = "#3b4949", --  8.53:1
  comment   = "#706776", --  4.90:1  mauve, darkened from 1.6:1 as given
  gutter    = "#8ca1bc", --  2.40:1

  -- A painting darkens a paper ground, so the comment colour darkens with it.
  comment_on_painting = "#605765", -- 4.56:1 against #ccd3d9

  amber     = "#14793f", --  4.97:1  the green, darkened to survive as text
  clay      = "#804c6e", --  6.00:1  mauve pulled toward plum
  sage      = "#2a6a4f", --  5.83:1  green softened toward steel
  slate     = "#395779", --  6.78:1  steel, deepened
  ochre     = "#1b5b37", --  7.34:1  green, deepest step
  rose      = "#ad3327", --  5.81:1

  add_bg    = "#dcece2",
  add_fg    = "#14793f",
  change_bg = "#dfe7f2",
  change_fg = "#395779",
  delete_bg = "#f6dedb",
  delete_fg = "#ad3327",
}

---@return table
function M.get()
  return vim.o.background == "light" and M.light or M.dark
end

return M
