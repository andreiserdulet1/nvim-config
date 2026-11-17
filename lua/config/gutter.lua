-- Clicking the sign column does something, as in JetBrains:
--
--   ▶ ✓ ✗ next to a test   → run that test
--   a git change marker    → show / stage / rollback that change
--
-- Anywhere else -- the text, the line numbers, a line with no sign -- a click
-- is an ordinary click.

local M = {}

-- Is the click left of the line numbers (the sign and fold columns)?
local function in_signs(pos)
  if pos.winid == 0 or pos.line == 0 then return false end
  local info = vim.fn.getwininfo(pos.winid)[1]
  if not info then return false end
  local wo = vim.wo[pos.winid]
  local numw = 0
  if wo.number or wo.relativenumber then
    local buf = vim.api.nvim_win_get_buf(pos.winid)
    numw = math.max(wo.numberwidth, #tostring(vim.api.nvim_buf_line_count(buf)) + 1)
  end
  return pos.wincol >= 1 and pos.wincol <= info.textoff - numw
end

local function on_click()
  local pos = vim.fn.getmousepos()
  if not in_signs(pos) then return "<LeftMouse>" end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  local name = vim.api.nvim_buf_get_name(buf)

  if name:match("%.spec%.ts$") then
    local tests = require("config.tests")
    for _, item in ipairs(tests.discover(buf)) do
      if item.line == pos.line then
        vim.schedule(function() tests.run(buf, pos.line) end)
        return ""
      end
    end
  end

  if require("config.vcs").hunk_at(buf, pos.line) then
    vim.schedule(function()
      vim.api.nvim_set_current_win(pos.winid)
      vim.api.nvim_win_set_cursor(pos.winid, { pos.line, 0 })
      require("config.vcs").hunk_menu()
    end)
    return ""
  end
  return "<LeftMouse>"
end

function M.setup()
  vim.keymap.set("n", "<LeftMouse>", on_click,
    { expr = true, desc = "Click: run a test / act on a git change in the gutter" })
end

return M
