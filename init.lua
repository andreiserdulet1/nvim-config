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

require("config.options")
require("config.lazy")
require("config.keymaps")
