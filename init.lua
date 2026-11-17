-- ============================================================================
--  Neovim IDE — Angular / TypeScript front-end (+ Terraform)
--  Layout:
--    lua/config/*   options, keymaps, cheatsheet, lazy bootstrap
--    lua/plugins/*  one file per concern (ui, editor, lsp, lint, git, term)
--  Press <Space>? at any time for the keymap cheatsheet.
-- ============================================================================

-- Leader must be set before lazy.nvim loads any plugin that defines keymaps.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Remember light/dark. Read before lazy.nvim starts so the theme is applied
-- without a flash of the wrong palette.
vim.g.nvim_theme_background = select(2, require("config.theme").load_saved())

require("config.options")

-- Apply the colourscheme before lazy.nvim loads anything. Graphite ships in
-- this repo (colors/graphite.lua), so there is no plugin to wait for.
require("config.theme").apply("graphite", vim.g.nvim_theme_background or "dark")

require("config.lazy")
require("config.keymaps")
require("config.menu").setup()
require("config.layout").setup()
require("config.copy").setup()
