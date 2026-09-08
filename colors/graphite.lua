-- Graphite. `~/.config/nvim` is already on the runtime path, so this file makes
-- `:colorscheme graphite` work with no plugin at all.
--
-- One name, two variants: it reads `vim.o.background`, which is why
-- config/theme.lua marks it `by_background`. The palette lives in
-- lua/scheme/palettes/graphite.lua and the shared engine in lua/scheme/init.lua.
require("scheme").load("graphite")
