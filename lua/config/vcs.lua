-- Git the way JetBrains lays it out: one menu (<leader>gv, right-click → Git…,
-- or right-click the branch in the statusline) with the file, the hunk under
-- the cursor and the repository, and every action you reach for daily --
-- add, rollback, stash / unstash, commit, push, pull, branches.
--
-- lazygit (<leader>gg) is still there for everything else; this is the quick
-- path for the common ones. Anything that throws work away (rollback, drop a
-- stash, undo a commit) asks first.

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "git" })
end

local function root(path)
  return vim.fs.root(path or 0, ".git") or vim.uv.cwd()
end

local function git(args, opts)
  opts = opts or {}
  local res = vim.system(vim.list_extend({ "git" }, args), { cwd = opts.cwd or root(), text = true }):wait()
  return res.code == 0, vim.trim(res.stdout or ""), vim.trim(res.stderr or "")
end

-- Long-running or networked commands: in the background, then a notification.
local function git_async(args, done_msg, cwd)
  notify("git " .. args[1] .. " …")
  vim.system(vim.list_extend({ "git" }, args), { cwd = cwd or root(), text = true }, function(res)
    vim.schedule(function()
      local out = vim.trim((res.stdout or "") .. "\n" .. (res.stderr or ""))
      if res.code == 0 then
        notify(done_msg .. (out ~= "" and ("\n" .. out:sub(1, 400)) or ""))
      else
        notify("git " .. args[1] .. " failed:\n" .. out:sub(1, 1500), vim.log.levels.ERROR)
      end
      vim.cmd("checktime")
      pcall(function() require("gitsigns").refresh() end)
    end)
  end)
end

local function confirm(question, yes, on_yes)
  vim.ui.select({ yes, "Cancel" }, { prompt = question }, function(c)
    if c == yes then on_yes() end
  end)
end

local function reload()
  vim.cmd("checktime")
  pcall(function() require("gitsigns").refresh() end)
end

local function file()
  local f = vim.api.nvim_buf_get_name(0)
  return (f ~= "" and vim.bo.buftype == "") and f or nil
end

local function tracked(path)
  return (git({ "ls-files", "--error-unmatch", "--", path }, { cwd = root(path) }))
end

---------------------------------------------------------------------------
-- File
---------------------------------------------------------------------------

function M.add(path)
  path = path or file()
  if not path then return end
  local ok, _, err = git({ "add", "--", path }, { cwd = root(path) })
  if ok then notify("Added " .. vim.fs.basename(path)) reload() else notify(err, vim.log.levels.ERROR) end
end

function M.unstage(path)
  path = path or file()
  if not path then return end
  local ok, _, err = git({ "restore", "--staged", "--", path }, { cwd = root(path) })
  if ok then notify("Unstaged " .. vim.fs.basename(path)) reload() else notify(err, vim.log.levels.ERROR) end
end

--- Throw away every change to this file, staged or not.
function M.rollback(path)
  path = path or file()
  if not path then return end
  if not tracked(path) then
    notify(vim.fs.basename(path) .. " is untracked — delete it from the tree if you don't want it",
      vim.log.levels.WARN)
    return
  end
  confirm("Rollback " .. vim.fs.basename(path) .. "? Your changes to it are lost.", "Rollback", function()
    local ok, _, err = git({ "restore", "--staged", "--worktree", "--", path }, { cwd = root(path) })
    if ok then notify("Rolled back " .. vim.fs.basename(path)) reload() else notify(err, vim.log.levels.ERROR) end
  end)
end

---------------------------------------------------------------------------
-- Hunk (via gitsigns)
---------------------------------------------------------------------------

--- The gitsigns hunk covering `line` in `buf`, if any.
function M.hunk_at(buf, line)
  local ok, hunks = pcall(function() return require("gitsigns").get_hunks(buf) end)
  if not ok or not hunks then return nil end
  for _, h in ipairs(hunks) do
    local first = h.added.start
    local last = first + math.max(h.added.count, 1) - 1
    if line >= first and line <= last then return h end
  end
end

--- What clicking a change marker in the gutter opens.
function M.hunk_menu()
  local gs = require("gitsigns")
  local items = {
    { "Show the change", function() gs.preview_hunk() end },
    { "Stage this change", function() gs.stage_hunk() end },
    { "Rollback this change", function() gs.reset_hunk() end },
    { "Blame this line", function() gs.blame_line({ full = true }) end },
    { "Diff the whole file", function() gs.diffthis() end },
  }
  vim.ui.select(items, { prompt = "Change", format_item = function(i) return i[1] end },
    function(i) if i then i[2]() end end)
end

---------------------------------------------------------------------------
-- Commit, push, pull
---------------------------------------------------------------------------

function M.commit(push)
  local _, staged = git({ "diff", "--cached", "--name-only" })
  local function ask()
    vim.ui.input({ prompt = "Commit message: " }, function(msg)
      if not msg or vim.trim(msg) == "" then return end
      notify("Committing … (hooks may take a moment)")
      vim.system({ "git", "commit", "-m", msg }, { cwd = root(), text = true }, function(res)
        vim.schedule(function()
          if res.code ~= 0 then
            require("config.scratch").open("commit-failed",
              (res.stdout or "") .. "\n" .. (res.stderr or ""), { scheme = "git" })
            notify("Commit failed — output opened beside", vim.log.levels.ERROR)
            return
          end
          notify("Committed: " .. msg)
          reload()
          if push then M.push() end
        end)
      end)
    end)
  end
  if staged ~= "" then ask() return end
  local _, changed = git({ "status", "--porcelain" })
  if changed == "" then notify("Nothing to commit") return end
  vim.ui.select({ "Stage every change (git add -A) and commit", "Open lazygit to choose", "Cancel" },
    { prompt = "Nothing is staged" }, function(c)
      if not c or c == "Cancel" then return end
      if c:match("^Open") then vim.cmd("LazyGit") return end
      git({ "add", "-A" })
      ask()
    end)
end

local function do_push()
  local _, upstream = git({ "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}" })
  if upstream == "" or upstream:match("fatal") then
    local _, branch = git({ "rev-parse", "--abbrev-ref", "HEAD" })
    git_async({ "push", "-u", "origin", branch }, "Pushed " .. branch .. " (upstream set)")
  else
    git_async({ "push" }, "Pushed")
  end
end

--- Push -- after types, lint and the headless tests pass, unless that is
--- turned off (<leader>uP). If they fail you can still push anyway.
function M.push()
  if not vim.g.check_before_push then do_push() return end
  require("config.check").run({ tests = true }, function(ok)
    if ok then do_push() return end
    vim.ui.select({ "Don't push — fix it first", "Push anyway" }, { prompt = "Checks failed" }, function(c)
      if c == "Push anyway" then do_push() end
    end)
  end)
end

function M.pull() git_async({ "pull", "--rebase", "--autostash" }, "Pulled") end
function M.fetch() git_async({ "fetch", "--all", "--prune" }, "Fetched") end

--- Undo the last commit, keeping its changes staged.
function M.undo_commit()
  local _, subject = git({ "log", "-1", "--format=%s" })
  local _, remote = git({ "branch", "-r", "--contains", "HEAD" })
  local warn = remote ~= "" and " It is already pushed — you'd need to force-push." or ""
  confirm("Undo \"" .. subject .. "\"? The changes stay staged." .. warn, "Undo commit", function()
    local ok, _, err = git({ "reset", "--soft", "HEAD~1" })
    if ok then notify("Undid \"" .. subject .. "\"") reload() else notify(err, vim.log.levels.ERROR) end
  end)
end

--- Throw away every uncommitted change in the repo (untracked files stay).
function M.rollback_all()
  local _, changed = git({ "status", "--porcelain", "--untracked-files=no" })
  if changed == "" then notify("No changes to roll back") return end
  local n = #vim.split(changed, "\n")
  confirm(("Rollback all changes in %d file(s)? This cannot be undone — stash instead to keep them."):format(n),
    "Rollback all", function()
      local ok, _, err = git({ "restore", "--staged", "--worktree", "--", "." })
      if ok then notify("Rolled back " .. n .. " file(s)") reload() else notify(err, vim.log.levels.ERROR) end
    end)
end

---------------------------------------------------------------------------
-- Stash ("shelve")
---------------------------------------------------------------------------

function M.stash()
  local _, changed = git({ "status", "--porcelain" })
  if changed == "" then notify("Nothing to stash") return end
  vim.ui.input({ prompt = "Stash message (optional): " }, function(msg)
    if msg == nil then return end
    local args = { "stash", "push", "--include-untracked" }
    if vim.trim(msg) ~= "" then vim.list_extend(args, { "-m", msg }) end
    local ok, out, err = git(args)
    if ok then notify(out) reload() else notify(err, vim.log.levels.ERROR) end
  end)
end

--- Pick a stash (with its diff as the preview), then apply, pop or drop it.
function M.unstash()
  local _, list = git({ "stash", "list", "--format=%gd\t%cr\t%gs" })
  if list == "" then notify("No stashes") return end
  local items = {}
  for i, line in ipairs(vim.split(list, "\n")) do
    local ref, when, msg = line:match("^(.-)\t(.-)\t(.*)$")
    items[i] = { idx = i, ref = ref, text = ref .. " " .. msg, when = when, msg = msg }
  end
  local r = root()
  Snacks.picker.pick({
    title = "Stashes",
    items = items,
    format = function(item)
      return { { ("%-11s"):format(item.ref), "Comment" }, { ("%-12s "):format(item.when), "Comment" }, { item.msg } }
    end,
    preview = function(ctx)
      local res = vim.system({ "git", "stash", "show", "-p", "--include-untracked", ctx.item.ref },
        { cwd = r, text = true }):wait()
      ctx.preview:reset()
      ctx.preview:set_lines(vim.split(res.stdout or "", "\n"))
      ctx.preview:highlight({ ft = "diff" })
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      vim.schedule(function()
        vim.ui.select({ "Pop (apply and remove)", "Apply (keep the stash)", "Drop (delete it)", "Cancel" },
          { prompt = item.ref .. " " .. item.msg }, function(c)
            if not c or c == "Cancel" then return end
            if c:match("^Drop") then
              confirm("Drop " .. item.ref .. "? Its changes are lost.", "Drop", function()
                local ok, out, err = git({ "stash", "drop", item.ref })
                notify(ok and out or err, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
              end)
              return
            end
            local verb = c:match("^Pop") and "pop" or "apply"
            local ok, out, err = git({ "stash", verb, item.ref })
            if ok then notify(verb == "pop" and ("Popped " .. item.ref) or ("Applied " .. item.ref)) reload()
            else notify(((out or "") .. "\n" .. (err or "")):sub(1, 1500), vim.log.levels.ERROR) end
          end)
      end)
    end,
  })
end

---------------------------------------------------------------------------
-- Branches
---------------------------------------------------------------------------

function M.branches()
  local _, out = git({ "for-each-ref", "--sort=-committerdate",
    "--format=%(refname:short)\t%(committerdate:relative)\t%(HEAD)\t%(upstream:track)\t.", "refs/heads", "refs/remotes/origin" })
  local items, seen = { { new = true, text = "+ New branch from here…" } }, {}
  for line in out:gmatch("[^\n]+") do
    -- The trailing "." keeps empty last fields from being trimmed away.
    local ref, when, head, track = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t%.$")
    if ref and ref ~= "origin/HEAD" and ref ~= "origin" then
      local short = ref:gsub("^origin/", "")
      if not seen[short] then
        seen[short] = true
        table.insert(items, { branch = short, remote = ref:match("^origin/") ~= nil, when = when,
          current = head == "*", track = track, text = short })
      end
    end
  end
  vim.ui.select(items, {
    prompt = "Branches",
    format_item = function(i)
      if i.new then return i.text end
      return ("%s %-45s %-14s %s%s"):format(i.current and "●" or " ", i.branch, i.when, i.track or "",
        i.remote and " (remote)" or "")
    end,
  }, function(choice)
    if not choice then return end
    if choice.new then
      vim.ui.input({ prompt = "New branch name: " }, function(name)
        if not name or vim.trim(name) == "" then return end
        local ok, _, err = git({ "switch", "-c", vim.trim(name) })
        if ok then notify("On new branch " .. name) reload() else notify(err, vim.log.levels.ERROR) end
      end)
      return
    end
    if choice.current then return end
    local ok, _, err = git({ "switch", choice.branch })
    if ok then
      notify("Switched to " .. choice.branch)
      reload()
    elseif err:match("would be overwritten") or err:match("local changes") then
      vim.ui.select({ "Stash my changes, then switch", "Cancel" }, { prompt = "You have local changes" }, function(c)
        if c and c:match("^Stash") then
          git({ "stash", "push", "--include-untracked", "-m", "auto: before switching to " .. choice.branch })
          local ok2, _, err2 = git({ "switch", choice.branch })
          if ok2 then notify("Stashed and switched to " .. choice.branch .. " — <leader>gU to get them back") reload()
          else notify(err2, vim.log.levels.ERROR) end
        end
      end)
    else
      notify(err, vim.log.levels.ERROR)
    end
  end)
end

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------

function M.menu()
  local f = file()
  local name = f and vim.fs.basename(f)
  local items = {}
  local function add(label, fn, cond)
    if cond ~= false then table.insert(items, { label = label, run = fn }) end
  end
  local hunk = f and M.hunk_at(0, vim.fn.line("."))
  add("Change here: show / stage / rollback…", M.hunk_menu, hunk ~= nil)
  if f then
    add("Add " .. name, function() M.add(f) end)
    add("Unstage " .. name, function() M.unstage(f) end)
    add("Rollback " .. name .. "…", function() M.rollback(f) end)
    add("Show diff of " .. name, function() vim.cmd("DiffviewOpen -- " .. vim.fn.fnameescape(f)) end)
    add("History of " .. name, function() vim.cmd("DiffviewFileHistory " .. vim.fn.fnameescape(f)) end)
    add("Annotate (blame)", function() require("gitsigns").blame() end)
    add("Compare " .. name .. " with branch…", function() require("config.compare").with_branch(f) end)
  end
  add("Commit…", function() M.commit(false) end)
  add("Commit and push…", function() M.commit(true) end)
  add("Push", M.push)
  add("Pull (rebase, autostash)", M.pull)
  add("Fetch", M.fetch)
  add("Branches…", M.branches)
  add("Stash changes…", M.stash)
  add("Unstash…", M.unstash)
  add("Show all changes", function() vim.cmd("DiffviewOpen") end)
  add("Undo last commit…", M.undo_commit)
  add("Rollback all changes…", M.rollback_all)
  add("lazygit", function() vim.cmd("LazyGit") end)
  vim.ui.select(items, { prompt = "Git", format_item = function(i) return i.label end },
    function(i) if i then i.run() end end)
end

return M
