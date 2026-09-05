-- ============================================================================
--  Neovim IDE — Angular / TypeScript + Terraform / Infrastructure
--  Layout:
--    lua/config/*   options, keymaps, cheatsheet, lazy bootstrap
--    lua/plugins/*  one file per concern (ui, editor, lsp, lint, git, term)
--  Press <Space>? at any time for the keymap cheatsheet.
-- ============================================================================

-- Leader must be set before lazy.nvim loads any plugin that defines keymaps.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Remember the colourscheme and light/dark choice. Read before lazy.nvim
-- starts so the theme can be applied without a flash of the wrong palette.
-- config/theme.lua also understands the older file that held only light/dark.
do
  local ok, theme = pcall(require, "config.theme")
  if ok then
    local scheme, bg = theme.load_saved()
    vim.g.nvim_theme_colorscheme = scheme
    vim.g.nvim_theme_background = bg
  end
end

-- A faded Dutch landscape behind the code, drawn by iTerm2 underneath a
-- transparent colourscheme. Decided here, before lazy.nvim loads, because both
-- colourschemes read the flag while building their highlights -- setting it
-- later would need a re-apply and a visible repaint.
--
-- Transparency is only turned on when a painting can actually appear: iTerm2 is
-- the only terminal that understands the escape code, and terminal/paintings/
-- import.sh has to have been run. A fresh clone that has done neither looks
-- completely normal rather than showing an editor with no background at all.
do
  local ok, painting = pcall(require, "config.painting")
  vim.g.graphite_transparent = ok
    and painting.supported()
    and painting.installed()
    and painting.choice() ~= painting.NONE
end

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.painting").setup()
