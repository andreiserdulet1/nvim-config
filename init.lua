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

-- Remember the light/dark choice made with <leader>ut.
local theme_file = vim.fn.stdpath("data") .. "/theme-background"
if vim.fn.filereadable(theme_file) == 1 then
  local saved = (vim.fn.readfile(theme_file)[1] or ""):gsub("%s", "")
  if saved == "light" or saved == "dark" then
    vim.g.nvim_theme_background = saved
  end
end

require("config.options")
require("config.lazy")
require("config.keymaps")
