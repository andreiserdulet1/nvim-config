-- Graphite: a warm-neutral colourscheme.
--
-- Warm greys rather than the blue-greys every other theme uses, with amber,
-- sage and clay carrying the syntax and a paper-like light variant.
--
-- Every text colour here was chosen against a measured WCAG contrast ratio
-- rather than by eye, and the ratio is recorded beside it. The first draft's
-- comment colours failed (3.92:1 dark, 3.84:1 light against a 4.5 target) and
-- were lightened and darkened respectively until they passed -- comments are
-- text you read, so they get held to the same bar as any other text.
--
-- Line numbers are the deliberate exception: they sit near 2.5:1 because a
-- gutter should be present without competing with the code. Holding them to
-- 4.5:1 would make them shout.

local M = {}

M.dark = {
  -- surfaces, lightest to darkest use
  ground    = "#17161a", -- Normal background
  surface   = "#1e1c21", -- floats, popups, sidebars
  raised    = "#252229", -- cursorline, subtle fills
  selection = "#302c33", -- visual selection
  border    = "#3a3540", -- window separators, float borders

  -- text
  text      = "#d6d0c8", -- 11.76:1
  dim       = "#b3aca3", --  8.02:1  operators, punctuation, secondary UI
  comment   = "#8b8274", --  4.75:1  raised from #7d7468, which failed at 3.92:1
  gutter    = "#5d5666", --  2.56:1  recessive on purpose

  -- Used in place of `comment` when a background painting is showing, and only
  -- then. A painting has to lift the ground above #17161a to be visible at all,
  -- and `comment` has almost no room to give: it sits at 4.75:1 against a 4.5:1
  -- floor. Measured against the lifted ground (#363436, the brightest the
  -- painting is allowed to reach), #8b8274 falls to 3.27:1 and this holds
  -- 4.51:1. Body text is 8.1:1 there and needs no adjustment.
  comment_on_painting = "#a39b8f", -- 4.51:1 against #363436

  -- syntax accents
  amber     = "#d9a05b", --  7.83:1  functions and methods
  clay      = "#c98a7a", --  6.35:1  keywords, control flow
  sage      = "#93a87e", --  6.98:1  strings
  slate     = "#8d9aa8", --  6.28:1  numbers, booleans, constants
  ochre     = "#c9b072", --  8.52:1  types, classes, interfaces
  rose      = "#d9737f", --  5.75:1  errors

  -- diff and git, as backgrounds tinted toward the accent they mean
  add_bg    = "#1e2a1e",
  add_fg    = "#93a87e",
  change_bg = "#2a2620",
  change_fg = "#c9b072",
  delete_bg = "#2e1f22",
  delete_fg = "#d9737f",
}

M.light = {
  ground    = "#faf7f2",
  surface   = "#ffffff",
  raised    = "#f0ebe2",
  selection = "#e4ddd1",
  border    = "#d6cec0",

  text      = "#23201c", -- 15.18:1
  dim       = "#4a453e", --  8.88:1
  comment   = "#736a5e", --  4.97:1  darkened from #857c70, which failed at 3.84:1
  -- The light side of the same problem: a painting darkens the paper ground
  -- rather than lifting it, so the comment colour has to darken to keep up.
  -- Against #d8d5d0 (the darkest the painting may reach) #736a5e falls to
  -- 3.62:1 and this holds 4.50:1; body text is 11.0:1 and is left alone.
  comment_on_painting = "#635c51", -- 4.50:1 against #d8d5d0
  gutter    = "#aca291", --  2.36:1  recessive on purpose

  amber     = "#8a5a1e", --  5.52:1
  clay      = "#9a4f3d", --  5.52:1
  sage      = "#4f6b3f", --  5.60:1
  slate     = "#4a5568", --  7.04:1
  ochre     = "#7a6420", --  5.35:1
  rose      = "#9a3f4d", --  6.16:1

  add_bg    = "#e6efdf",
  add_fg    = "#4f6b3f",
  change_bg = "#f3ecd9",
  change_fg = "#7a6420",
  delete_bg = "#f7e2e2",
  delete_fg = "#9a3f4d",
}

---@return table
function M.get()
  return vim.o.background == "light" and M.light or M.dark
end

return M
