-- A lualine theme for Graphite.
--
-- This exists because lualine's `theme = "auto"` produced an unreadable
-- statusline against this palette -- measured 3.34:1 for the mode block and
-- 3.19:1 for the section beside it, both below the 4.5:1 floor, grey on grey.
-- Deriving the colours explicitly puts every section between 5.7:1 and 10.2:1.
--
-- The mode colour is the background with the editor's ground as the text, so
-- the current mode reads as a solid chip rather than tinted text.
--
-- `get()` returns a PLAIN table, rebuilt on each call. An earlier version used
-- a metatable with __index/__pairs to resolve lazily; that silently produced an
-- empty statusline, because Neovim runs LuaJIT and LuaJIT has no __pairs, so
-- lualine's `pairs(theme)` iterated nothing.

local M = {}

--- Build the theme for the palette matching the current `background`.
---@return table
function M.get()
  local c = require("graphite.palette").get()

  local function chip(colour)
    return { fg = c.ground, bg = colour, gui = "bold" }
  end
  local b = { fg = c.text, bg = c.raised }
  local body = { fg = c.dim, bg = c.surface }
  local quiet = { fg = c.comment, bg = c.surface }

  return {
    normal   = { a = chip(c.amber), b = b, c = body },
    insert   = { a = chip(c.sage),  b = b, c = body },
    visual   = { a = chip(c.clay),  b = b, c = body },
    replace  = { a = chip(c.rose),  b = b, c = body },
    command  = { a = chip(c.ochre), b = b, c = body },
    terminal = { a = chip(c.slate), b = b, c = body },
    inactive = { a = quiet, b = quiet, c = quiet },
  }
end

return M
