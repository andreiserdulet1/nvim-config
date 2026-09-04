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

require("config.options")
require("config.lazy")
require("config.keymaps")
