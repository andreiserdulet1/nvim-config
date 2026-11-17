-- Finding conflicted files, and resolving them with the mouse.
--
-- "Unmerged paths" is git's term for files left in conflict by a merge, rebase
-- or cherry-pick. `git diff --diff-filter=U` is the reliable way to list them —
-- more so than parsing `git status`, whose output format is meant for humans.

local M = {}

--- Absolute paths of every conflicted file in the current repo.
function M.unmerged()
  local root = vim.fs.root(0, ".git")
  if not root then return {} end

  local out = vim.system(
    { "git", "diff", "--name-only", "--diff-filter=U", "--relative" },
    { cwd = root, text = true }
  ):wait()

  if out.code ~= 0 then return {} end

  local files = {}
  for line in (out.stdout or ""):gmatch("[^\r\n]+") do
    if line ~= "" then
      table.insert(files, root .. "/" .. line)
    end
  end
  return files
end

--- Put the conflicted files in the quickfix list, so ]q and [q walk them.
function M.to_quickfix()
  local files = M.unmerged()
  if #files == 0 then
    vim.notify("No conflicts in this repo")
    return
  end

  local items = {}
  for _, path in ipairs(files) do
    -- Point at the first conflict marker in each file rather than line 1, so
    -- jumping to an entry lands where the work actually is.
    local lnum = 1
    local ok, lines = pcall(vim.fn.readfile, path)
    if ok then
      for i, line in ipairs(lines) do
        if line:match("^<<<<<<<") then lnum = i break end
      end
    end
    table.insert(items, { filename = path, lnum = lnum, text = "conflict" })
  end

  vim.fn.setqflist({}, " ", { title = "Conflicts", items = items })
  vim.cmd("copen")
end

-- Resolving conflicts with the mouse -----------------------------------------
--
-- WebStorm's merge dialog is three panes and one idea: the middle pane is the
-- file you are producing, the outer two are where the content comes from, and
-- you click the side you want. This is that, built out of the pieces diffview
-- already has -- its diff3_horizontal layout, its conflict parser, and its
-- conflict actions, so a click and its keypress do the same thing to the
-- buffer rather than being two implementations of the same idea.
--
--   left pane    double-click a line  -> take OURS for the conflict beside it
--   middle pane  double-click a marker -> take that side
--                right-click           -> every choice, including neither
--   right pane   double-click a line  -> take THEIRS for that conflict
--
-- Each pane says what it is in its winbar, and the middle one counts the
-- conflicts down as you resolve them.

local ns_hints = vim.api.nvim_create_namespace("conflict_hints")
local ns_current = vim.api.nvim_create_namespace("conflict_current")

-- Parsing the whole buffer on every cursor move would be wasteful in a large
-- file, and the cursor moves a lot. changedtick invalidates this exactly when
-- the text changes and never otherwise.
local cache = {}

---@return table[] conflicts, as diffview parses them
local function parse(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return {} end

  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local hit = cache[buf]
  if hit and hit.tick == tick then return hit.conflicts end

  local ok, vcs = pcall(require, "diffview.vcs.utils")
  if not ok then return {} end

  local conflicts = vcs.parse_conflicts(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) or {}
  cache[buf] = { tick = tick, conflicts = conflicts }
  return conflicts
end

--- The middle pane of the merge view on this tab page, if one is open.
local function result_pane()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.b[buf].conflict_result then return win, buf end
  end
end

--- Which conflict the cursor sits in: the conflict itself, and its number.
local function current(win, buf)
  local conflicts = parse(buf)
  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  for i, conflict in ipairs(conflicts) do
    if lnum >= conflict.first and lnum <= conflict.last then
      return conflict, i, #conflicts
    end
  end
  return nil, nil, #conflicts
end

local refresh -- declared here because choose() below calls it

--- Run one of diffview's conflict actions in the window that was clicked.
--- The window is passed explicitly because the menu runs its choice after the
--- picker has closed, by which point the current window may be anyone.
local function choose(winid, which, whole_file)
  local actions = require("diffview.actions")
  local action = whole_file and actions.conflict_choose_all(which)
    or actions.conflict_choose(which)
  if not vim.api.nvim_win_is_valid(winid) then return end

  local buf = vim.api.nvim_win_get_buf(winid)
  vim.api.nvim_win_call(winid, action)
  vim.schedule(function() refresh(buf) end)
end

-- What each pane says about itself ------------------------------------------

local function set_winbar(win, text)
  if vim.api.nvim_win_is_valid(win) then
    pcall(function() vim.wo[win].winbar = text end)
  end
end

--- Keep the middle pane's winbar counting: "conflict 2 of 5", then done.
local function update_winbar()
  local win, buf = result_pane()
  if not win then return end

  local _, index, total = current(win, buf)
  if total == 0 then
    set_winbar(win, " RESULT   all conflicts resolved -- :w to finish")
  elseif index then
    set_winbar(win, (" RESULT   conflict %d of %d -- double-click a marker, or right-click")
      :format(index, total))
  else
    set_winbar(win, (" RESULT   %d conflict%s left -- ]x for the next one")
      :format(total, total == 1 and "" or "s"))
  end
end

--- Shade the conflict the cursor is in, so it is obvious which one a click
--- in an outer pane will land on.
local function highlight_current()
  local win, buf = result_pane()
  if not win then return end

  vim.api.nvim_buf_clear_namespace(buf, ns_current, 0, -1)
  local conflict = current(win, buf)
  if not conflict then return end

  for lnum = conflict.first, conflict.last do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns_current, lnum - 1, 0, {
      line_hl_group = "CursorLine",
    })
  end
end

--- Say, on each marker line, what clicking it will do.
---@return integer count how many conflicts are left
function M.hints(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return 0 end
  vim.api.nvim_buf_clear_namespace(buf, ns_hints, 0, -1)

  local conflicts = parse(buf)
  local function hint(lnum, text)
    if not lnum then return end
    pcall(vim.api.nvim_buf_set_extmark, buf, ns_hints, lnum - 1, 0, {
      virt_text = { { "   " .. text, "Comment" } },
      virt_text_pos = "eol",
    })
  end

  for _, conflict in ipairs(conflicts) do
    -- ours.first is the <<<<<<< line, theirs.first the =======, theirs.last the
    -- >>>>>>>, and base.first the ||||||| you only get with conflictStyle=diff3.
    hint(conflict.ours.first, "double-click: keep this side")
    hint(conflict.base.first, "double-click: keep the common ancestor")
    hint(conflict.theirs.first, "double-click: keep both")
    hint(conflict.theirs.last, "double-click: keep this side")
  end

  return #conflicts
end

--- Redraw everything that tracks the conflicts, and stand down once there are
--- none left. Called after every choice rather than left to TextChanged:
--- diffview edits the buffer through the API, which does not reliably raise it.
function refresh(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end

  local count = M.hints(buf)
  update_winbar()
  highlight_current()
  if count > 0 or not vim.b[buf].conflict_mouse then return end

  -- Give the double click back to selecting a word, which is what it does in
  -- every other buffer.
  vim.b[buf].conflict_mouse = nil
  pcall(vim.keymap.del, "n", "<2-LeftMouse>", { buffer = buf })
  pcall(vim.keymap.del, "n", "<RightMouse>", { buffer = buf })
  vim.notify(
    vim.fs.basename(vim.api.nvim_buf_get_name(buf))
      .. ": all conflicts resolved. :w to finish, <tab> for the next file"
  )
end

-- The gestures ---------------------------------------------------------------

--- The buffer line shown at a given screen row in `win`.
---
--- The three panes are in diff mode and share a row of the screen, so Neovim
--- has already aligned them with filler lines: the same screen row is the same
--- place in the file in all three. That is what makes a click in an outer pane
--- findable in the middle one, and it is exact rather than a guess at which
--- conflict was meant. Filler lines belong to no line at all, so a click on one
--- falls back to the last real line above it.
local function line_at_screenrow(win, screenrow)
  local best
  for lnum = vim.fn.line("w0", win), vim.fn.line("w$", win) do
    local row = vim.fn.screenpos(win, lnum, 1).row
    if row == screenrow then return lnum end
    if row > 0 and row < screenrow then best = lnum end
  end
  return best
end

--- Take the side of the pane that was double-clicked, for the conflict that
--- sits beside the click. WebStorm's accept arrows, without the arrows.
local function take_side(which)
  local win, buf = result_pane()
  if not win then return end

  local lnum = line_at_screenrow(win, vim.fn.getmousepos().screenrow)
  if not lnum then return end

  for _, conflict in ipairs(parse(buf)) do
    if lnum >= conflict.first and lnum <= conflict.last then
      vim.api.nvim_win_set_cursor(win, { conflict.first, 0 })
      choose(win, which)
      return
    end
  end

  vim.notify("Double-click beside a conflict to take that side", vim.log.levels.WARN)
end

--- Take the side whose marker was double-clicked, in the middle pane.
local function on_click()
  local line = vim.api.nvim_get_current_line()
  local winid = vim.api.nvim_get_current_win()

  if line:match("^<<<<<<<") then
    choose(winid, "ours")
  elseif line:match("^|||||||") then
    choose(winid, "base")
  elseif line:match("^=======$") then
    choose(winid, "all")
  elseif line:match("^>>>>>>>") then
    choose(winid, "theirs")
  end
end

--- The right-click menu, for the choices a marker line cannot express.
function M.menu()
  local winid = vim.api.nvim_get_current_win()

  -- Mapping <RightMouse> takes over from mousemodel=popup_setpos and the cursor
  -- move that normally comes with it, so without this the menu would act on
  -- whichever conflict was selected before the click.
  local pos = vim.fn.getmousepos()
  if pos.winid == winid and pos.line > 0 then
    pcall(vim.api.nvim_win_set_cursor, winid, { pos.line, 0 })
  end

  local items = {
    { label = "Keep this side (ours, left)", run = function() choose(winid, "ours") end },
    { label = "Keep the other side (theirs, right)", run = function() choose(winid, "theirs") end },
    { label = "Keep both", run = function() choose(winid, "all") end },
    { label = "Keep neither", run = function() choose(winid, "none") end },
    { label = "Keep the common ancestor", run = function() choose(winid, "base") end },
    { label = "Whole file: keep ours", run = function() choose(winid, "ours", true) end },
    { label = "Whole file: keep theirs", run = function() choose(winid, "theirs", true) end },
  }

  vim.ui.select(items, {
    prompt = "This conflict",
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice then choice.run() end
  end)
end

-- Full-width panes ------------------------------------------------------------
--
-- WebStorm opens a merge in a window of its own containing nothing but the
-- three versions. diffview keeps its file panel down the left, which is about
-- thirty columns the middle pane would rather have -- and the middle pane is
-- the one you read most closely, since it is the only one you are editing.
--
-- Once per tab page, not once per file: <leader>b brings the panel back, and
-- asking for it should mean it stays until you leave.
local widened = {}

local function widen()
  local ok, lib = pcall(require, "diffview.lib")
  if not ok then return end

  local view = lib.get_current_view()
  if not view or not view.panel or widened[view.tabpage] then return end
  widened[view.tabpage] = true

  -- Scheduled: this runs from inside diffview's own window setup, and closing
  -- a window underneath it is not something to do while it is still arranging.
  vim.schedule(function()
    if view.panel:is_open() then
      view.panel:close()
    end
  end)
end

--- Forget a closed view, so the next merge on that tab page starts wide again.
--- Wired to diffview's view_closed hook in plugins/git.lua.
function M.forget(view)
  if view and view.tabpage then
    widened[view.tabpage] = nil
  end
end

--- Wire the mouse into the merge view. Called from diffview's
--- diff_buf_win_enter hook once per pane; see the spec in plugins/git.lua.
function M.attach(buf, winid, ctx)
  -- diff3 and diff4 are the merge layouts. Gating on them keeps all of this
  -- off the ordinary two-pane diff view, where the symbols mean something else
  -- entirely -- "b" there is the new state of a file, not a merge in progress.
  if not (ctx.layout_name or ""):match("^diff[34]") then return end

  -- The outer panes: OURS on the left, THEIRS on the right. Read-only versions
  -- of the file, so the double click has nothing better to do than take one.
  if ctx.symbol == "a" or ctx.symbol == "c" then
    local ours = ctx.symbol == "a"
    set_winbar(winid, ours and " OURS   what you had -- double-click a line to take it"
      or " THEIRS   what came in -- double-click a line to take it")
    vim.keymap.set("n", "<2-LeftMouse>", function()
      take_side(ours and "ours" or "theirs")
    end, { buffer = buf, desc = "Take this side for the conflict you clicked" })
    return
  end

  -- The middle pane: the file as it exists on disk, the one you are producing.
  if ctx.symbol ~= "b" or #parse(buf) == 0 or vim.b[buf].conflict_mouse then return end
  vim.b[buf].conflict_result = true
  vim.b[buf].conflict_mouse = true
  widen()

  vim.keymap.set("n", "<2-LeftMouse>", on_click, {
    buffer = buf,
    desc = "Keep the side you double-clicked",
  })
  vim.keymap.set("n", "<RightMouse>", M.menu, {
    buffer = buf,
    desc = "What to do with this conflict",
  })

  local group = vim.api.nvim_create_augroup("conflict_view_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    buffer = buf,
    group = group,
    callback = function() refresh(buf) end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    group = group,
    callback = function()
      update_winbar()
      highlight_current()
    end,
  })

  refresh(buf)
end

return M
