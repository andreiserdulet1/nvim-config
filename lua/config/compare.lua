-- Before / after, and two repos at once.
--
-- For migrations and "what changed": compare a file with the same file in
-- another repo, with another branch, with the clipboard or with any other
-- file; compare two whole repos or folders file by file; or open a second
-- repo next to this one -- in its own tab or a split -- where the pickers,
-- grep, terminals and the dev servers all work in that repo.
--
-- Every comparison opens in a new tab so your layout is untouched; the bar on
-- top says which side is which, and ✕ (or <leader>Dq) closes it.

local M = {}

local EXCLUDE = { "node_modules", ".git", "dist", ".angular", "coverage", ".terraform", ".DS_Store" }

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "compare" })
end

local function root_of(path)
  return vim.fs.root(path, ".git") or vim.fs.dirname(path)
end

local function short(path)
  return (vim.fn.fnamemodify(path, ":~"))
end

-- "remote-ui-template/src/app" rather than just "app".
local function label(path)
  local root = root_of(path)
  local name = vim.fs.basename(root)
  return path == root and name or (name .. "/" .. path:sub(#root + 2))
end

---------------------------------------------------------------------------
-- The diff tab
---------------------------------------------------------------------------

function _G.ConfigCompareClose()
  vim.schedule(function() M.close() end)
end

local function bar(label)
  return "%#WinBar# " .. label:gsub("%%", "%%%%") .. "%=%#Comment#%@v:lua.ConfigCompareClose@ ✕ close comparison %X"
end

--- Close the comparison tab you're in.
function M.close()
  if not vim.t.config_compare then notify("Not in a comparison tab") return end
  vim.cmd("diffoff!")
  if #vim.api.nvim_list_tabpages() > 1 then vim.cmd("tabclose") else vim.cmd("only | enew") end
end

-- A side is a path, or { name = string, lines = string[], ft = string } for
-- text that is not a file (the clipboard, a file at another revision).
local function open_side(side, cmd)
  if type(side) == "string" then
    vim.cmd(cmd .. " " .. vim.fn.fnameescape(side))
  else
    vim.cmd(cmd == "edit" and "enew" or "vnew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, side.lines)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = side.ft or ""
    pcall(vim.api.nvim_buf_set_name, buf, "compare://" .. side.name)
  end
  vim.cmd("diffthis")
end

--- Diff two sides in a new tab: left, then right.
function M.diff(left, right, left_label, right_label)
  vim.cmd("tabnew")
  vim.t.config_compare = true
  open_side(left, "edit")
  vim.wo.winbar = bar("◀ " .. (left_label or (type(left) == "string" and short(left) or left.name)))
  open_side(right, "rightbelow vsplit")
  vim.wo.winbar = bar("▶ " .. (right_label or (type(right) == "string" and short(right) or right.name)))
  pcall(vim.cmd, "normal! gg]c")   -- straight to the first change
end

---------------------------------------------------------------------------
-- Picking the other side
---------------------------------------------------------------------------

local function pick_project(prompt, cb)
  require("config.projects").choose(prompt, cb)
end

--- This file against the same path in another repo -- or, when that repo has
--- no such file, a file you pick there.
function M.with_other_repo(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if path == "" then notify("Not a file") return end
  local root = root_of(path)
  local rel = path:sub(#root + 2)
  pick_project("Compare " .. rel .. " with the same file in…", function(other)
    local candidate = other .. "/" .. rel
    if vim.uv.fs_stat(candidate) then
      M.diff(path, candidate, vim.fs.basename(root) .. "/" .. rel, vim.fs.basename(other) .. "/" .. rel)
      return
    end
    notify("No " .. rel .. " in " .. vim.fs.basename(other) .. " — pick the file to compare with")
    Snacks.picker.files({
      cwd = other,
      pattern = vim.fs.basename(path),
      confirm = function(picker, item)
        picker:close()
        if item then
          vim.schedule(function() M.diff(path, Snacks.picker.util.path(item)) end)
        end
      end,
    })
  end)
end

--- This file against any other file (in any repo).
function M.with_file(path)
  path = path or vim.api.nvim_buf_get_name(0)
  Snacks.picker.files({
    title = "Compare with…",
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() M.diff(path, Snacks.picker.util.path(item)) end) end
    end,
  })
end

--- This file against another open buffer.
function M.with_buffer()
  local path = vim.api.nvim_buf_get_name(0)
  Snacks.picker.buffers({
    title = "Compare with open file…",
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() M.diff(path, vim.api.nvim_buf_get_name(item.buf)) end) end
    end,
  })
end

--- The selection (or the whole file) against what is on the clipboard.
function M.with_clipboard()
  local mode = vim.fn.mode()
  local l1, l2 = 1, vim.api.nvim_buf_line_count(0)
  if mode == "v" or mode == "V" or mode == "\22" then
    l1, l2 = vim.fn.line("v"), vim.fn.line(".")
    if l1 > l2 then l1, l2 = l2, l1 end
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
  end
  local ft = vim.bo.filetype
  local mine = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)
  local clip = vim.split(vim.fn.getreg("+"), "\n", { plain = true })
  M.diff({ name = "selection", lines = mine, ft = ft }, { name = "clipboard", lines = clip, ft = ft },
    "this " .. (l2 - l1 + 1 < vim.api.nvim_buf_line_count(0) and "selection" or "file"), "clipboard")
end

--- This file against another branch (or tag, or commit).
function M.with_branch(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if path == "" then notify("Not a file") return end
  local root = root_of(path)
  local res = vim.system({ "git", "for-each-ref", "--sort=-committerdate", "--format=%(refname:short)",
    "refs/heads", "refs/remotes/origin" }, { cwd = root, text = true }):wait()
  local refs = vim.tbl_filter(function(r) return r ~= "origin/HEAD" and r ~= "origin" end,
    vim.split(vim.trim(res.stdout or ""), "\n"))
  vim.ui.select(refs, { prompt = "Compare with branch" }, function(ref)
    if not ref then return end
    local rel = path:sub(#root + 2)
    local show = vim.system({ "git", "show", ref .. ":" .. rel }, { cwd = root, text = true }):wait()
    if show.code ~= 0 then notify(rel .. " does not exist on " .. ref, vim.log.levels.WARN) return end
    local ft = vim.filetype.match({ filename = path }) or ""
    M.diff({ name = ref .. ":" .. rel, lines = vim.split(show.stdout:gsub("\n$", ""), "\n"), ft = ft }, path,
      ref, "working copy")
  end)
end

--- Everything above, as one menu.
function M.menu(path)
  path = path or vim.api.nvim_buf_get_name(0)
  local items = {
    { "The same file in another repo", function() M.with_other_repo(path) end },
    { "Another branch", function() M.with_branch(path) end },
    { "Another open file", M.with_buffer },
    { "Any file…", function() M.with_file(path) end },
    { "The clipboard", M.with_clipboard },
    { "Two whole repos / folders…", M.folders },
  }
  vim.ui.select(items, {
    prompt = "Compare " .. vim.fs.basename(path) .. " with…",
    format_item = function(i) return i[1] end,
  }, function(i) if i then i[2]() end end)
end

--- Called from the file tree's right-click: a folder compares as a folder.
function M.pick_other(path)
  if vim.fn.isdirectory(path) == 1 then
    M.folders(path)
  else
    M.menu(path)
  end
end

---------------------------------------------------------------------------
-- Two folders, file by file
---------------------------------------------------------------------------

local function list_differences(a, b)
  local args = { "diff", "-rq" }
  for _, x in ipairs(EXCLUDE) do vim.list_extend(args, { "-x", x }) end
  vim.list_extend(args, { a, b })
  local res = vim.system(args, { text = true }):wait()
  local items = {}
  for line in (res.stdout or ""):gmatch("[^\n]+") do
    local fa, fb = line:match("^Files (.-) and (.-) differ$")
    if fa then
      table.insert(items, { status = "M", rel = fa:sub(#a + 2), left = fa, right = fb })
    else
      local dir, name = line:match("^Only in (.-): (.+)$")
      if dir then
        local full = dir .. "/" .. name
        if vim.startswith(full, a .. "/") then
          table.insert(items, { status = "−", rel = full:sub(#a + 2), left = full })
        else
          table.insert(items, { status = "+", rel = full:sub(#b + 2), right = full })
        end
      end
    end
  end
  table.sort(items, function(x, y) return x.rel < y.rel end)
  return items
end

--- Show every file that differs between two folders; pick one to diff it.
--- With no argument you choose both repos; a subfolder narrows it, so
--- comparing src/app/feature/payments across two repos is one step.
function M.folders(start)
  local function go(a, b)
    a, b = vim.fs.normalize(a), vim.fs.normalize(b)
    notify("Comparing " .. short(a) .. " ↔ " .. short(b) .. " …")
    local items = list_differences(a, b)
    if #items == 0 then notify("No differences") return end
    for i, it in ipairs(items) do
      it.idx, it.text = i, it.status .. " " .. it.rel
    end
    Snacks.picker.pick({
      title = ("%s ↔ %s   (%d files)   − only left  + only right  M changed"):format(
        label(a), label(b), #items),
      items = items,
      -- The unified diff, worked out only for the file you're on.
      preview = function(ctx)
        local it = ctx.item
        local text = it.left and it.right
          and vim.system({ "diff", "-u", it.left, it.right }, { text = true }):wait().stdout
          or ("Only in " .. short(it.left or it.right))
        ctx.preview:reset()
        ctx.preview:set_lines(vim.split(text, "\n"))
        ctx.preview:highlight({ ft = "diff" })
      end,
      format = function(item)
        local hl = ({ M = "DiagnosticWarn", ["+"] = "DiagnosticOk", ["−"] = "DiagnosticError" })[item.status]
        return { { item.status .. " ", hl }, { item.rel } }
      end,
      confirm = function(picker, item)
        picker:close()
        if not item then return end
        vim.schedule(function()
          if item.left and item.right then
            M.diff(item.left, item.right, label(a) .. "/" .. item.rel, label(b) .. "/" .. item.rel)
          else
            vim.cmd("tabnew " .. vim.fn.fnameescape(item.left or item.right))
          end
          notify("<leader>fc goes back to the list")
        end)
      end,
    })
  end

  -- Starting from a folder in the tree: the same subfolder in another repo.
  if start then
    local root = root_of(start)
    local sub = start:sub(#root + 2)
    pick_project("Compare " .. (sub ~= "" and sub or vim.fs.basename(root)) .. " with the same folder in…", function(other)
      go(start, other .. (sub ~= "" and ("/" .. sub) or ""))
    end)
    return
  end

  pick_project("Compare: left repo", function(a)
    pick_project("Compare " .. vim.fs.basename(a) .. " with…", function(b)
      vim.ui.input({ prompt = "Only this subfolder (blank for everything): ", default = "src/" }, function(sub)
        if sub == nil then return end
        sub = vim.trim(sub):gsub("/$", "")
        go(sub ~= "" and (a .. "/" .. sub) or a, sub ~= "" and (b .. "/" .. sub) or b)
      end)
    end)
  end)
end

---------------------------------------------------------------------------
-- A second repo, open at the same time
---------------------------------------------------------------------------

--- Another repo in a new tab, with that tab's working directory set to it.
--- Pickers, grep, the tree, terminals and <leader>ns all act on that repo
--- while you're in the tab; gt / gT (or click the tab top-right) switches.
function M.project_tab()
  pick_project("Open in a new tab", function(dir)
    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(dir))
    vim.t.project = vim.fs.basename(dir)
    Snacks.picker.files({ cwd = dir })
  end)
end

--- Another repo in a split beside this one, with a window-local directory.
function M.project_split()
  pick_project("Open beside this one", function(dir)
    vim.cmd("rightbelow vsplit")
    vim.cmd("lcd " .. vim.fn.fnameescape(dir))
    vim.cmd("enew")
    Snacks.picker.files({ cwd = dir })
  end)
end

return M
