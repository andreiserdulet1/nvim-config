-- Graphite. `~/.config/nvim` is already on the runtime path, so this file makes
-- `:colorscheme graphite` work with no plugin at all.
--
-- One name, two variants: it reads `vim.o.background`, the same mechanism
-- tokyonight uses, which is why config/theme.lua marks it `by_background`.
require("graphite").load()
