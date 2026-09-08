-- Umber: the colours of the paintings that sit behind the editor.
--
-- Named for the earth pigment these painters ground their darks from, and
-- derived from the paintings themselves rather than chosen. All eight sources
-- in terminal/paintings/src/ were quantised, pooled -- 183 colours weighted by
-- pixel count -- and clustered by hue:
--
--   #1b130e  15.2%  near-black       -> the dark ground
--   #49341e  26.1%  deep umber       -> surface, raised, gutter
--   #a99c7c  21.5%  warm mid         -> dim, and the comment hue
--   #62635e  22.5%  neutral grey     -> folded into the two above
--   #96723a   6.6%  gold / ochre     -> amber, functions
--   #ebead8   6.2%  cream highlight  -> the light ground, and dark's text
--   #a8ae96   1.7%  olive foliage    -> sage, strings
--   #b3cbca   0.3%  slate sky        -> slate, numbers
--
-- Rembrandt's red-brown #53261a supplies clay and rose. It is the one strong
-- hue in the set that is neither earth nor sky, so it carries keywords and
-- errors, which are the two things that must not be mistaken for anything else.
--
-- The point of the ground being #1b130e is that it is the paintings' OWN
-- darkest tone. import.sh maps each painting's black point onto the ground, so
-- with this theme the image has no edge at all -- there is no rectangle, the
-- picture just dissolves into the page.
--
-- Unlike Heather, nothing here had to be abandoned: an earth palette already
-- lives in the range text occupies. The gold needed darkening for the light
-- variant (#96723a -> #7b5e30) and that is the only compromise.
--
-- Ratios are measured and recorded. Line numbers sit near 2.4:1 on purpose.

local M = {}

M.dark = {
  ground    = "#1b130e", -- the paintings' own darkest tone
  surface   = "#302215",
  raised    = "#3b2a19",
  selection = "#604726",
  border    = "#6b583f",

  -- The furthest the ground may travel toward `text` while
  -- `comment_on_painting` still clears 4.5:1. terminal/paintings/import.sh
  -- reads this and maps each painting's white point onto it.
  ceiling   = "#3a332c",

  text      = "#ebead8", -- 15.09:1  the cream highlight
  dim       = "#a99c7c", --  6.75:1  the warm mid, as clustered
  comment   = "#8f8467", --  4.94:1  warm mid, desaturated
  gutter    = "#68523b", --  2.49:1  umber; recessive on purpose

  comment_on_painting = "#a79c80", -- 4.56:1 against #3a332c

  amber     = "#c5a26a", --  7.63:1  gold -- functions
  clay      = "#c77f6b", --  5.83:1  Rembrandt red-brown -- keywords
  sage      = "#9ca388", --  6.99:1  olive foliage -- strings
  slate     = "#6ea2a0", --  6.40:1  slate sky -- numbers
  ochre     = "#c9b798", --  9.35:1  gold toward cream -- types
  rose      = "#ca7a74", --  5.71:1  red-brown, lifted -- errors

  add_bg    = "#20240f",
  add_fg    = "#9ca388",
  change_bg = "#2e2513",
  change_fg = "#c5a26a",
  delete_bg = "#301813",
  delete_fg = "#ca7a74",
}

M.light = {
  ground    = "#ebead8", -- the cream highlight becomes the paper
  surface   = "#f7f7ef",
  raised    = "#dcdac7",
  selection = "#d3c8ac",
  border    = "#b7b09c",

  -- A painting darkens paper rather than lifting it, so the ramp runs the other
  -- way: the painting's blacks land here and its whites on the ground.
  ceiling   = "#cac9ba",

  text      = "#1b130e", -- 15.09:1
  dim       = "#513921", --  8.84:1
  comment   = "#7a5f42", --  4.88:1
  gutter    = "#ab947b", --  2.38:1

  comment_on_painting = "#684f36", -- 4.56:1 against #cac9ba

  amber     = "#7b5e30", --  4.96:1  gold, darkened to survive as text
  clay      = "#893f2b", --  6.16:1
  sage      = "#526127", --  5.58:1
  slate     = "#2e5553", --  6.81:1
  ochre     = "#5d4524", --  7.38:1
  rose      = "#9d3529", --  5.81:1

  add_bg    = "#e2e6cf",
  add_fg    = "#526127",
  change_bg = "#f0e6cd",
  change_fg = "#7b5e30",
  delete_bg = "#f4ddd6",
  delete_fg = "#9d3529",
}

---@return table
function M.get()
  return vim.o.background == "light" and M.light or M.dark
end

return M
