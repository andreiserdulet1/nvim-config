-- Heather: pale lilac paper, with orange, plum and deep teal doing the work.
--
-- Built from five colours:
--
--   #ECE5F0  lilac    the light ground
--   #E98A15  orange   the signature accent
--   #59114D  plum
--   #003B36  teal
--   #012622  ink      the dark ground
--
-- The light and dark variants are the same five colours with their roles
-- swapped -- lilac is the ground in one and the text in the other -- rather
-- than a second palette invented to sit beside the first.
--
-- Every text colour was chosen against a measured WCAG ratio, recorded beside
-- it, exactly as in graphite.lua. Two of the given colours cannot be used as
-- given, and that is worth stating plainly:
--
--   * #E98A15 on #ECE5F0 measures 2.10:1. As body text that is unreadable, so
--     the light variant darkens it to #8e540d (4.97:1) for functions and keeps
--     the pure orange only where it sits BEHIND text -- the cursor, IncSearch,
--     the lualine mode chip -- where it is a background and the ratio is
--     measured the other way round.
--   * #59114D and #003B36 on #012622 measure 1.24:1 and 1.29:1. The dark
--     variant lightens both until they clear 6:1.
--
-- Line numbers are the deliberate exception at ~2.4:1: a gutter should be
-- present without competing with the code.

local M = {}

M.light = {
  ground    = "#ECE5F0", -- the lilac, as given
  surface   = "#f6f3f8",
  raised    = "#e2d6e5",
  selection = "#d3c1d4",
  border    = "#c3aac2",

  -- A painting darkens paper rather than lifting it, so the ramp runs the
  -- other way: the painting's blacks land here and its whites on the ground.
  ceiling   = "#cbc5ce",

  text      = "#012622", -- 13.09:1  the ink, as given
  dim       = "#003B36", -- 10.15:1  the teal, as given
  comment   = "#7f5578", --  4.90:1  plum, desaturated and lightened to clear 4.5
  gutter    = "#ac8da7", --  2.39:1  recessive on purpose

  -- A painting darkens a paper ground rather than lifting it, so the comment
  -- colour has to darken to keep up. Measured against #cbc5ce, the darkest the
  -- painting is allowed to reach.
  comment_on_painting = "#684361", -- 4.84:1 against #cbc5ce

  amber     = "#8e540d", --  4.97:1  the orange, darkened to survive as text
  clay      = "#951c80", --  6.18:1  plum, lifted off the ink
  sage      = "#00655d", --  5.64:1  teal
  slate     = "#484872", --  6.96:1  teal blended toward plum
  ochre     = "#784118", --  6.63:1  warm, one step deeper than amber
  rose      = "#a22b40", --  5.76:1  plum pulled toward red

  add_bg    = "#dfeae4",
  add_fg    = "#00655d",
  change_bg = "#f2e5d8",
  change_fg = "#784118",
  delete_bg = "#f5dde1",
  delete_fg = "#a22b40",
}

M.dark = {
  ground    = "#012622", -- the ink, as given
  surface   = "#00322d",
  raised    = "#003732", -- the teal, essentially, as a raised fill
  selection = "#311a3a",
  border    = "#426b6a",

  -- The furthest the ground may travel toward `text` while
  -- `comment_on_painting` still clears 4.5:1. terminal/paintings/import.sh
  -- reads this and maps each painting's white point onto it.
  ceiling   = "#22423f",

  text      = "#ECE5F0", -- 13.09:1  the lilac, as given
  dim       = "#c1b2c9", --  8.05:1  lilac, desaturated
  comment   = "#b678ac", --  4.82:1  plum, lightened from 1.24:1 as given
  gutter    = "#814d78", --  2.51:1

  -- A painting lifts a dark ground, which costs comments their margin.
  comment_on_painting = "#c898c0", -- 4.54:1 against #22423f

  amber     = "#E98A15", --  6.23:1  the orange, exactly as given
  clay      = "#d185c4", --  6.04:1  plum, lightened
  sage      = "#58b7af", --  6.77:1  teal, lightened
  slate     = "#86aaab", --  6.42:1  teal blended toward lilac
  ochre     = "#edb068", --  8.46:1  orange, lifted a step above amber
  rose      = "#da848f", --  5.90:1

  add_bg    = "#04302a",
  add_fg    = "#58b7af",
  change_bg = "#2c2415",
  change_fg = "#edb068",
  delete_bg = "#331d24",
  delete_fg = "#da848f",
}

---@return table
function M.get()
  return vim.o.background == "light" and M.light or M.dark
end

return M
