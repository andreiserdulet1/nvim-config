-- Where terminals sit, and a clickable bar on top of each one.
--
-- Every terminal window -- a toggleterm shell, a dev server's output, Claude --
-- gets a winbar with its name and four buttons:
--
--   ⇱ float   ⬓ bottom   ◨ right   ✕ hide
--
-- so a terminal can be moved or put away with the mouse alone. The keyboard
-- equivalents are <leader>tm (terminals) and <leader>ap (Claude).

local M = {}

M.positions = { "float", "bottom", "right" }

local function claude_buf(buf)
  local ok, b = pcall(function() return require("claudecode.terminal").get_active_terminal_bufnr() end)
  return ok and b == buf
end

local function toggleterm_of(buf)
  local ok, terms = pcall(require, "toggleterm.terminal")
  if not ok then return nil end
  for _, t in ipairs(terms.get_all(true)) do
    if t.bufnr == buf then return t end
  end
end

local DIRECTION = { float = "float", bottom = "horizontal", right = "vertical" }

--- Move the terminal shown in `win` to `pos` ("float" | "bottom" | "right" | "left").
function M.move(win, pos)
  if not win or win == 0 then win = vim.api.nvim_get_current_win() end
  local buf = vim.api.nvim_win_get_buf(win)

  if claude_buf(buf) then
    require("config.claude").move(pos)
    return
  end

  local term = toggleterm_of(buf)
  if term then
    term:close()
    local size = pos == "right" and math.floor(vim.o.columns * 0.4) or math.floor(vim.o.lines * 0.35)
    term:open(size, DIRECTION[pos] or "float")
    return
  end

  -- Anything else: a plain window move.
  local cmd = ({ right = "L", left = "H", bottom = "J" })[pos]
  if cmd then vim.api.nvim_win_call(win, function() vim.cmd("wincmd " .. cmd) end) end
end

--- Cycle the current terminal through float → bottom → right.
function M.cycle()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "terminal" then
    vim.notify("Not in a terminal — <leader>tl to pick one")
    return
  end
  local cfg = vim.api.nvim_win_get_config(win)
  local cur = cfg.relative ~= "" and "float"
    or (vim.api.nvim_win_get_width(win) < vim.o.columns and "right" or "bottom")
  local i = vim.fn.index(M.positions, cur)
  M.move(win, M.positions[(i + 1) % #M.positions + 1])
end

--- Hide the terminal in `win` without stopping what runs in it.
function M.hide(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if claude_buf(buf) then
    require("config.claude").toggle()
    return
  end
  local term = toggleterm_of(buf)
  if term then term:close() return end
  pcall(vim.api.nvim_win_close, win, false)
end

---------------------------------------------------------------------------
-- The winbar
---------------------------------------------------------------------------

local ACTIONS = { "float", "bottom", "right", "hide" }

-- Statusline click handlers must be named functions; minwid says which button.
function _G.ConfigTermButton(minwid)
  local win = vim.fn.getmousepos().winid
  if win == 0 then win = vim.api.nvim_get_current_win() end
  local action = ACTIONS[minwid]
  vim.schedule(function()
    if action == "hide" then M.hide(win) else M.move(win, action) end
  end)
end

local function button(i, label)
  return ("%%%d@v:lua.ConfigTermButton@ %s %%X"):format(i, label)
end

local function title(buf)
  if claude_buf(buf) then return "✦ Claude" end
  local term = toggleterm_of(buf)
  if term then
    return "  " .. (term.display_name or ("terminal " .. term.id))
  end
  return "  terminal"
end

function M.winbar(buf)
  return table.concat({
    "%#WinBar#", title(buf):gsub("%%", "%%%%"), "%=",
    "%#Comment#",
    button(1, "⇱ float"), button(2, "⬓ bottom"), button(3, "◨ right"), button(4, "✕ hide"),
  })
end

-- Lazygit and other full-screen tools in a terminal draw their own chrome.
local function wants_bar(buf)
  if vim.bo[buf].buftype ~= "terminal" then return false end
  local name = vim.api.nvim_buf_get_name(buf)
  return not name:match("lazygit") and not name:match("jira")
end

function M.setup()
  vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter", "WinNew" }, {
    group = vim.api.nvim_create_augroup("config_term_winbar", { clear = true }),
    callback = function()
      -- Scheduled: toggleterm and snacks set window options after these fire.
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if wants_bar(buf) and vim.wo[win].winbar == "" then
            vim.wo[win].winbar = M.winbar(buf)
          end
          if wants_bar(buf) and not vim.b[buf].config_term_menu then
            vim.b[buf].config_term_menu = true
            for _, mode in ipairs({ "n", "t" }) do
              vim.keymap.set(mode, "<RightMouse>", function() require("config.menu").terminal() end,
                { buffer = buf, desc = "Terminal menu" })
            end
          end
        end
      end)
    end,
  })
end

return M
