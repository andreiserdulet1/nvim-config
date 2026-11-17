-- Claude, beyond what claudecode.nvim gives out of the box.
--
--   - where its window sits (right / left / bottom / float), remembered
--   - continuing the last conversation, or resuming any earlier one from a
--     picker that shows what each one was about
--   - asking about the code you are looking at, fixing the diagnostics under
--     the cursor, and handing it a dev server's error output
--
-- Text is typed into Claude's prompt with claudecode's send_to_terminal, which
-- is what you would do by hand. When Claude is not running yet, the prompt is
-- passed on its command line instead, so the first question starts it.

local M = {}

local STATE = vim.fn.stdpath("data") .. "/claude_layout"
M.positions = { "right", "bottom", "float", "left" }

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "claude" })
end

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------

function M.position()
  local ok, lines = pcall(vim.fn.readfile, STATE)
  local pos = ok and lines[1] or nil
  return vim.tbl_contains(M.positions, pos) and pos or "right"
end

--- claudecode's terminal options for a position. Passed on every open/toggle,
--- so a hidden Claude comes back wherever it was last put.
function M.opts(pos)
  pos = pos or M.position()
  if pos == "float" then
    return { snacks_win_opts = { position = "float", width = 0.85, height = 0.85, border = "rounded" } }
  end
  if pos == "bottom" then
    return { snacks_win_opts = { position = "bottom", height = 0.4 } }
  end
  return { split_side = pos, snacks_win_opts = { position = pos } }
end

local function term_api() return require("claudecode.terminal") end

local function bufnr()
  local ok, b = pcall(function() return term_api().get_active_terminal_bufnr() end)
  return ok and b and vim.api.nvim_buf_is_valid(b) and b or nil
end

function M.is_running() return bufnr() ~= nil end

local function visible_win()
  local b = bufnr()
  if not b then return nil end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    -- A hidden float is still in the window list; it is not on screen.
    if vim.api.nvim_win_get_buf(w) == b and not vim.api.nvim_win_get_config(w).hide then return w end
  end
end

--- Show / hide Claude, starting it if needed.
---@param args string|nil extra arguments for the `claude` command
function M.toggle(args)
  require("lazy").load({ plugins = { "claudecode.nvim" } })
  term_api().simple_toggle(M.opts(), args)
end

--- Focus Claude (or hide it if already focused).
function M.focus()
  require("lazy").load({ plugins = { "claudecode.nvim" } })
  term_api().focus_toggle(M.opts())
end

--- Move Claude to `pos` and remember it.
---
--- claudecode only hides Claude's window -- it keeps a float around hidden, and
--- re-creates a float from the options it was born with -- so moving means
--- closing the window for real, updating those options, and showing it again.
--- The conversation is untouched: only the window goes.
function M.move(pos)
  pcall(vim.fn.writefile, { pos }, STATE)
  local b = bufnr()
  if not b then
    notify("Claude will open on the " .. pos)
    return
  end

  local snacks_term
  for _, t in ipairs(Snacks.terminal.list()) do
    if t.buf == b then snacks_term = t end
  end
  if not snacks_term then
    notify("Could not find Claude's window to move; it will use the " .. pos .. " next time it starts",
      vim.log.levels.WARN)
    return
  end

  local win = snacks_term.win
  if win and vim.api.nvim_win_is_valid(win) then
    local floating = vim.api.nvim_win_get_config(win).relative ~= ""
    if floating and snacks_term._cc and snacks_term._cc.orig_hide then
      pcall(snacks_term._cc.orig_hide, snacks_term)
    end
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
  end
  snacks_term.win = nil
  if snacks_term._cc then snacks_term._cc.kind = nil end

  local o = M.opts(pos).snacks_win_opts
  snacks_term.opts.position = o.position
  snacks_term.opts.width = o.width or 0.38
  snacks_term.opts.height = o.height or 0
  snacks_term.opts.border = o.border or "none"

  term_api().simple_toggle(M.opts(pos))
end

--- Next position in the cycle.
function M.cycle()
  local cur = M.position()
  local i = (vim.fn.index(M.positions, cur) + 1) % #M.positions
  M.move(M.positions[i + 1])
  notify("Claude: " .. M.positions[i + 1])
end

--- Pick a position.
function M.layout_menu()
  vim.ui.select(M.positions, {
    prompt = "Put Claude on the…",
    format_item = function(p) return (p == M.position() and "● " or "  ") .. p end,
  }, function(p) if p then M.move(p) end end)
end

--- Grow or shrink Claude's split.
function M.resize(delta)
  local w = visible_win()
  if not w then return end
  if vim.api.nvim_win_get_config(w).relative ~= "" then return end
  if M.position() == "bottom" then
    vim.api.nvim_win_set_height(w, vim.api.nvim_win_get_height(w) + delta)
  else
    vim.api.nvim_win_set_width(w, vim.api.nvim_win_get_width(w) + delta * 2)
  end
end

---------------------------------------------------------------------------
-- Conversations
---------------------------------------------------------------------------

local function ensure_stopped(then_)
  if not M.is_running() then then_() return end
  vim.ui.select({ "Yes — close the current conversation", "No" }, {
    prompt = "Claude is already running here",
  }, function(c)
    if c and c:match("^Yes") then
      term_api().close()
      vim.defer_fn(then_, 200)
    end
  end)
end

--- Carry on with the most recent conversation in this directory.
function M.continue()
  ensure_stopped(function() M.toggle("--continue") end)
end

--- Start a fresh conversation (clears the current one).
function M.new()
  if M.is_running() then
    term_api().send_to_terminal("/clear")
    M.toggle_visible()
  else
    M.toggle()
  end
end

function M.toggle_visible()
  if not visible_win() then M.toggle() end
end

-- Claude Code keeps each conversation as ~/.claude/projects/<cwd>/<id>.jsonl,
-- where <cwd> is the absolute path with every / and . turned into -.
local function sessions_dir()
  local cwd = vim.fn.getcwd():gsub("[/%.]", "-")
  return vim.fn.expand("~/.claude/projects/") .. cwd
end

-- The first thing you typed, which is the best one-line summary there is.
local function first_prompt(path)
  local ok, lines = pcall(vim.fn.readfile, path, "", 80)
  if not ok then return nil end
  for _, line in ipairs(lines) do
    local dok, entry = pcall(vim.json.decode, line)
    if dok and type(entry) == "table" and entry.type == "user" and type(entry.message) == "table" then
      local content = entry.message.content
      if type(content) == "table" then
        for _, part in ipairs(content) do
          if type(part) == "table" and part.type == "text" then content = part.text break end
        end
      end
      -- Skip the harness's own preamble entries.
      if type(content) == "string" and not content:match("^%s*<") then
        return (content:gsub("%s+", " "))
      end
    end
  end
end

local function age(mtime)
  local mins = math.floor((os.time() - mtime) / 60)
  if mins < 60 then return mins .. "m" end
  if mins < 1440 then return math.floor(mins / 60) .. "h" end
  return math.floor(mins / 1440) .. "d"
end

--- Pick an earlier conversation from this project and resume it.
function M.resume()
  local dir = sessions_dir()
  local items = {}
  for name, t in vim.fs.dir(dir) do
    if t == "file" and name:match("%.jsonl$") then
      local path = dir .. "/" .. name
      local stat = vim.uv.fs_stat(path)
      local prompt = first_prompt(path)
      if stat and prompt then
        table.insert(items, {
          id = name:gsub("%.jsonl$", ""),
          mtime = stat.mtime.sec,
          text = prompt,
        })
      end
    end
  end
  if #items == 0 then
    -- Unknown layout or nothing saved: let Claude's own picker handle it.
    ensure_stopped(function() M.toggle("--resume") end)
    return
  end
  table.sort(items, function(a, b) return a.mtime > b.mtime end)

  vim.ui.select(items, {
    prompt = "Resume a conversation",
    format_item = function(i) return string.format("%-4s %s", age(i.mtime), i.text:sub(1, 110)) end,
  }, function(choice)
    if choice then
      ensure_stopped(function() M.toggle("--resume " .. choice.id) end)
    end
  end)
end

---------------------------------------------------------------------------
-- Asking
---------------------------------------------------------------------------

--- Send `text` to Claude: typed into the prompt if it is running, otherwise
--- passed as the opening prompt.
function M.ask_with(text)
  if M.is_running() then
    term_api().send_to_terminal(text)
    M.toggle_visible()
  else
    M.toggle(vim.fn.shellescape(text))
  end
end

local function where(l1, l2)
  local file = vim.fn.expand("%:.")
  if file == "" then return nil end
  if l1 and l2 and l1 ~= l2 then return ("@%s#L%d-%d"):format(file, l1, l2) end
  return ("@%s#L%d"):format(file, l1 or vim.fn.line("."))
end

local function range()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local a, b = vim.fn.line("v"), vim.fn.line(".")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
    return math.min(a, b), math.max(a, b)
  end
  local l = vim.fn.line(".")
  return l, l
end

--- Ask a question about the line or selection you are on.
function M.ask()
  local l1, l2 = range()
  local ref = where(l1, l2)
  vim.ui.input({ prompt = "Ask Claude" .. (ref and (" about " .. ref) or "") .. ": " }, function(q)
    if not q or vim.trim(q) == "" then return end
    M.ask_with(ref and (ref .. " " .. q) or q)
  end)
end

--- Fix the diagnostics on the current line or selection.
function M.fix()
  local l1, l2 = range()
  local ref = where(l1, l2)
  if not ref then notify("Not a file") return end
  local lines = {}
  for _, d in ipairs(vim.diagnostic.get(0)) do
    if d.lnum + 1 >= l1 and d.lnum + 1 <= l2 then
      table.insert(lines, ("- line %d: %s%s"):format(d.lnum + 1, d.message:gsub("\n", " "),
        d.source and (" (" .. d.source .. ")") or ""))
    end
  end
  if #lines == 0 then notify("No diagnostics here") return end
  M.ask_with(("Fix these diagnostics in %s:\n%s"):format(ref, table.concat(lines, "\n")))
end

--- Explain the line or selection.
function M.explain()
  local l1, l2 = range()
  local ref = where(l1, l2)
  if ref then M.ask_with("Explain " .. ref .. " — what it does and why, briefly.") end
end

--- Write or extend the spec for the current component.
function M.spec()
  local file = vim.fn.expand("%:.")
  if file == "" then return end
  local spec = require("config.component").sibling_path("spec")
  local target = spec and vim.fn.fnamemodify(spec, ":.") or nil
  M.ask_with(("Write or extend unit tests for @%s%s, following the conventions of the existing specs in this repo.")
    :format(file, target and (" in " .. target) or ""))
end

--- Review what is uncommitted.
function M.review()
  M.ask_with("Review my uncommitted changes (git diff) for bugs and anything that doesn't match this repo's conventions.")
end

--- Statusline label.
function M.status()
  return M.is_running() and "✦ Claude" or "✧ Claude"
end

return M
