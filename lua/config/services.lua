-- Long-running dev processes: the dev server, its wiremock, and shell-ui.
--
-- Every front-end repo in ~/projects has the same shape -- `yarn start` serves
-- the app, `yarn wiremock` serves the stubs -- and remotes are usually run
-- inside shell-ui, the host. This starts that set from whatever project you
-- are in, shows it in the statusline, and stops it again.
--
-- Each service is a hidden toggleterm terminal running the named yarn script
-- directly (not a shell with the command typed into it), so:
--   - its exit code is real: a crash is reported, not hidden behind a prompt
--   - stopping is one jobstop, which hangs up the whole process group --
--     ng serve's workers and wiremock's java go with it
--   - the output stays in the buffer after it exits, for reading or sending to
--     Claude
-- direnv's .envrc is loaded with `direnv exec` when direnv is installed,
-- because a non-interactive command never runs the shell's direnv hook.
--
-- With shell-ui, only shell-ui's wiremock runs: it owns the stubs the host
-- needs, and a remote's own wiremock is for running that remote standalone.

local M = {}

M.shell_ui = vim.fn.expand("~/projects/shell-ui")

-- Display order in the statusline and pickers.
local ORDER = { "app", "mock", "shell", "shell-mock" }

-- What each process prints once it is actually serving. Matched against a
-- rolling, colour-stripped tail of the output, because a pty delivers it in
-- arbitrary chunks that split lines (and URLs) in half.
-- The dev server's URL counts too: the esbuild builder prints it only once it
-- is listening. "bundle generation complete" does not -- it comes before that.
local READY = {
  "Compiled successfully",
  "port:%s+%d+",                 -- wiremock's banner
  "Started Wire[Mm]ock",
}
local URL = {
  "open your browser on (https?://[^%s%*]+)",
  "Local:%s+(https?://[^%s%*]+)",
}

---@class Service
---@field name string
---@field label string
---@field dir string
---@field script string
---@field branch string|nil
---@field state "starting"|"ready"|"crashed"|"exited"
---@field url string|nil
---@field term table toggleterm Terminal

---@type table<string, Service>
M.running = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "services" })
end

local function refresh_statusline()
  local ok, lualine = pcall(require, "lualine")
  if ok then pcall(lualine.refresh) end
end

local function git(dir, args)
  local res = vim.system(vim.list_extend({ "git" }, args), { cwd = dir, text = true }):wait()
  return res.code == 0, vim.trim(res.stdout or ""), vim.trim(res.stderr or "")
end

--- The project you are in: the repo's own package.json, not a nested library's.
local function project()
  local scripts = require("config.scripts")
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then dir = vim.uv.cwd() end
  local root = vim.fs.root(dir, ".git")
  if root and vim.uv.fs_stat(root .. "/package.json") then
    return scripts.decode(root .. "/package.json")
  end
  return scripts.project()
end

local function is_alive(svc)
  return svc and (svc.state == "starting" or svc.state == "ready")
end

--- Start one service. Replaces a dead one of the same name; leaves a live one.
local function start(name, label, dir, script, extra)
  local existing = M.running[name]
  if is_alive(existing) then return existing end
  if existing then pcall(function() existing.term:shutdown() end) end

  local cmd = "yarn " .. script
  if vim.fn.executable("direnv") == 1 and vim.uv.fs_stat(dir .. "/.envrc") then
    cmd = "direnv exec . " .. cmd
  end

  ---@type Service
  local svc = vim.tbl_extend("force", {
    name = name, label = label, dir = dir, script = script, state = "starting",
  }, extra or {})

  svc.term = require("toggleterm.terminal").Terminal:new({
    cmd = cmd,
    dir = dir,
    hidden = true,              -- not in <C-\> / :TermSelect rotation
    direction = "float",
    close_on_exit = false,      -- keep the output after a crash
    display_name = name .. " · " .. label,
    service = name,             -- lets the window layout code recognise it
    on_stdout = function(_, _, data)
      if not data or (svc.state ~= "starting" and svc.url) then return end
      svc.tail = ((svc.tail or "") .. table.concat(data, "\n")):sub(-4000)
      local clean = svc.tail:gsub("\27%[[%d;?]*%a", ""):gsub("\r", "")
      if not svc.url then
        for _, pat in ipairs(URL) do
          svc.url = clean:match(pat)
          if svc.url then break end
        end
      end
      if svc.state ~= "starting" then return end
      for _, pat in ipairs(READY) do
        if svc.url or clean:match(pat) then
          svc.state = "ready"
          svc.tail = nil
          vim.schedule(function()
            notify(("%s ready%s"):format(svc.label, svc.url and (" — " .. svc.url) or ""))
            refresh_statusline()
          end)
          return
        end
      end
    end,
    on_exit = function(_, _, code)
      if M.running[name] ~= svc then return end
      -- 129/143 are SIGHUP/SIGTERM: that is us stopping it, not a crash.
      local stopped = svc.stopping or code == 129 or code == 143
      svc.state = (code == 0 or stopped) and "exited" or "crashed"
      vim.schedule(function()
        if svc.state == "crashed" then
          notify(("%s exited with code %d — <leader>nv to read it, <leader>ae to send it to Claude")
            :format(svc.label, code), vim.log.levels.ERROR)
        elseif not stopped then
          notify(svc.label .. " exited")
        end
        refresh_statusline()
      end)
    end,
  })
  svc.term:spawn()   -- runs in the background; <leader>nv shows it
  M.running[name] = svc
  refresh_statusline()
  return svc
end

---------------------------------------------------------------------------
-- Starting
---------------------------------------------------------------------------

--- `yarn start` and `yarn wiremock` for the project you are in.
function M.start()
  local proj, err = project()
  if not proj then notify(err, vim.log.levels.WARN) return end
  if not proj.scripts.start then
    notify("No 'start' script in " .. proj.name, vim.log.levels.WARN)
    return
  end
  local name = vim.fs.basename(proj.root)
  start("app", name, proj.root, "start")
  if proj.scripts.wiremock then start("mock", name .. " wiremock", proj.root, "wiremock") end
  notify("Starting " .. name .. (proj.scripts.wiremock and " + wiremock" or ""))
end

-- Branches newest first: local ones, then remote ones with no local copy.
local function shell_branches()
  local ok, out = git(M.shell_ui, {
    "for-each-ref", "--sort=-committerdate",
    "--format=%(refname:short)\t%(committerdate:relative)\t%(HEAD)",
    "refs/heads", "refs/remotes/origin",
  })
  if not ok then return nil end
  local list, seen = {}, {}
  for line in out:gmatch("[^\n]+") do
    local ref, when, head = line:match("^(.-)\t(.-)\t(.*)$")
    if ref and ref ~= "origin/HEAD" and ref ~= "origin" then
      local short = ref:gsub("^origin/", "")
      if not seen[short] then
        seen[short] = true
        table.insert(list, {
          branch = short, remote_only = ref:match("^origin/") ~= nil,
          when = when, current = head == "*",
        })
      end
    end
  end
  return list
end

--- Put shell-ui on `branch`, installing dependencies only if they changed.
--- Calls `done()` once it is ready to start.
local function prepare_shell(branch, done)
  local ok, before = git(M.shell_ui, { "rev-parse", "HEAD" })
  if not ok then notify("shell-ui is not a git repo?", vim.log.levels.ERROR) return end

  local _, current = git(M.shell_ui, { "rev-parse", "--abbrev-ref", "HEAD" })
  if current ~= branch then
    local _, dirty = git(M.shell_ui, { "status", "--porcelain", "--untracked-files=no" })
    if dirty ~= "" then
      notify("shell-ui has uncommitted changes on " .. current
        .. " — commit or stash them before switching branch", vim.log.levels.ERROR)
      return
    end
    local sok, _, serr = git(M.shell_ui, { "switch", branch })
    if not sok then
      notify("Could not switch shell-ui to " .. branch .. ":\n" .. serr, vim.log.levels.ERROR)
      return
    end
    notify("shell-ui → " .. branch)
  end

  local _, after = git(M.shell_ui, { "rev-parse", "HEAD" })
  local lock_same = vim.system({ "git", "diff", "--quiet", before, after, "--", "yarn.lock" },
    { cwd = M.shell_ui }):wait().code == 0
  if lock_same and vim.uv.fs_stat(M.shell_ui .. "/node_modules") then
    done()
    return
  end

  notify("shell-ui's yarn.lock changed — running yarn install first")
  require("toggleterm.terminal").Terminal:new({
    cmd = "yarn install --frozen-lockfile",
    dir = M.shell_ui,
    direction = "float",
    close_on_exit = false,
    hidden = true,
    display_name = "shell-ui · yarn install",
    on_exit = function(t, _, code)
      vim.schedule(function()
        if code ~= 0 then
          notify("yarn install failed in shell-ui — see the terminal", vim.log.levels.ERROR)
          t:open()
          return
        end
        t:shutdown()
        done()
      end)
    end,
  }):spawn()
end

--- The current project served inside shell-ui, on a shell-ui branch you pick.
function M.start_with_shell()
  if vim.fn.isdirectory(M.shell_ui) == 0 then
    notify("No shell-ui at " .. M.shell_ui, vim.log.levels.ERROR)
    return
  end
  local proj, err = project()
  if not proj then notify(err, vim.log.levels.WARN) return end
  if vim.fs.normalize(proj.root) == vim.fs.normalize(M.shell_ui) then
    M.start()   -- you are in shell-ui itself
    return
  end

  local branches = shell_branches()
  if not branches or #branches == 0 then
    notify("Could not list shell-ui branches", vim.log.levels.ERROR)
    return
  end

  vim.ui.select(branches, {
    prompt = "shell-ui branch",
    format_item = function(b)
      return string.format("%s %-40s %s%s", b.current and "●" or " ", b.branch, b.when,
        b.remote_only and "  (remote)" or "")
    end,
  }, function(choice)
    if not choice then return end
    -- shell-ui's own processes are tied to its branch; restart them if it changes.
    local shell = M.running.shell
    if is_alive(shell) and shell.branch ~= choice.branch then
      M.stop({ "shell", "shell-mock" })
    end
    -- A remote's own wiremock would fight shell-ui's for the stubs.
    if is_alive(M.running.mock) then M.stop({ "mock" }) end

    prepare_shell(choice.branch, function()
      local name = vim.fs.basename(proj.root)
      local sproj = require("config.scripts").decode(M.shell_ui .. "/package.json") or { scripts = {} }
      start("shell", "shell-ui", M.shell_ui, "start", { branch = choice.branch })
      if sproj.scripts.wiremock then
        start("shell-mock", "shell-ui wiremock", M.shell_ui, "wiremock", { branch = choice.branch })
      end
      start("app", name, proj.root, "start")
      notify(("Starting shell-ui (%s) + %s"):format(choice.branch, name))
    end)
  end)
end

---------------------------------------------------------------------------
-- Stopping, viewing
---------------------------------------------------------------------------

local function list(filter)
  local out = {}
  for _, name in ipairs(ORDER) do
    local svc = M.running[name]
    if svc and (not filter or filter(svc)) then table.insert(out, svc) end
  end
  return out
end

--- Stop services by name, or all of them.
---@param names string[]|nil
function M.stop(names)
  local stopped = 0
  for _, svc in ipairs(list()) do
    if not names or vim.tbl_contains(names, svc.name) then
      svc.stopping = true
      if is_alive(svc) then stopped = stopped + 1 end
      pcall(vim.fn.jobstop, svc.term.job_id)
      pcall(function() svc.term:shutdown() end)
      M.running[svc.name] = nil
    end
  end
  if not names then notify(stopped > 0 and ("Stopped " .. stopped .. " service(s)") or "Nothing was running") end
  refresh_statusline()
end

local function format_svc(svc)
  local icon = ({ starting = "◌", ready = "●", crashed = "✗", exited = "○" })[svc.state]
  return string.format("%s %-11s %-28s %s", icon, svc.name, svc.label .. (svc.branch and (" @" .. svc.branch) or ""),
    svc.url or svc.state)
end

local function pick(prompt, cb)
  local items = list()
  if #items == 0 then notify("Nothing is running — <leader>ns to start") return end
  if #items == 1 then cb(items[1]) return end
  vim.ui.select(items, { prompt = prompt, format_item = format_svc }, function(s) if s then cb(s) end end)
end

--- Stop one service.
function M.stop_pick()
  pick("Stop", function(svc) M.stop({ svc.name }) end)
end

--- Open a service's output in a float.
function M.logs(name)
  if name and M.running[name] then
    M.running[name].term:toggle()
    return
  end
  pick("Show output", function(svc) svc.term:toggle() end)
end

--- Stop and start again with the same settings.
function M.restart()
  pick("Restart", function(svc)
    local s = { name = svc.name, label = svc.label, dir = svc.dir, script = svc.script, branch = svc.branch }
    M.stop({ s.name })
    vim.defer_fn(function() start(s.name, s.label, s.dir, s.script, { branch = s.branch }) end, 500)
  end)
end

--- The last lines a service printed, for Claude.
---@return string|nil text, Service|nil svc
function M.output(name, max_lines)
  local svc = M.running[name]
  if not svc or not svc.term.bufnr or not vim.api.nvim_buf_is_valid(svc.term.bufnr) then return nil end
  local lines = vim.api.nvim_buf_get_lines(svc.term.bufnr, 0, -1, false)
  while #lines > 0 and vim.trim(lines[#lines]) == "" do table.remove(lines) end
  local from = math.max(1, #lines - (max_lines or 80) + 1)
  return table.concat(vim.list_slice(lines, from), "\n"), svc
end

--- Pick a service and send its recent output to Claude.
function M.send_to_claude()
  pick("Send output to Claude", function(svc)
    local text = M.output(svc.name)
    if not text or text == "" then notify("No output from " .. svc.label) return end
    require("config.claude").ask_with(string.format(
      "`yarn %s` in %s printed the output below. Find the cause and fix it.\n```\n%s\n```",
      svc.script, vim.fn.fnamemodify(svc.dir, ":~"), text))
  end)
end

--- Everything above, as one menu -- what clicking the statusline opens.
function M.menu()
  local live = #list(is_alive) > 0
  local items = {
    { l = "▶  Start this project (yarn start + wiremock)", f = M.start },
    { l = "▶  Start inside shell-ui (pick a branch)", f = M.start_with_shell },
  }
  if #list() > 0 then
    vim.list_extend(items, {
      { l = "▤  Show output", f = M.logs },
      { l = "↻  Restart one", f = M.restart },
      { l = "✦  Send output to Claude", f = M.send_to_claude },
      { l = "■  Stop one", f = M.stop_pick },
      { l = "■  Stop everything", f = function() M.stop() end },
    })
  end
  vim.ui.select(items, {
    prompt = live and "Services" or "Services (nothing running)",
    format_item = function(i) return i.l end,
  }, function(i) if i then i.f() end end)
end

---------------------------------------------------------------------------
-- Statusline
---------------------------------------------------------------------------

--- "▶ Run" when idle, otherwise a dot per service.
function M.status()
  local items = list()
  if #items == 0 then return "▶ Run" end
  local parts = {}
  for _, svc in ipairs(items) do
    local icon = ({ starting = "◌", ready = "●", crashed = "✗", exited = "○" })[svc.state]
    table.insert(parts, icon .. " " .. svc.name .. (svc.name == "shell" and svc.branch and ("@" .. svc.branch) or ""))
  end
  return table.concat(parts, "  ")
end

--- Highlight for the whole component: the worst state wins.
function M.status_hl()
  local worst = nil
  for _, svc in ipairs(list()) do
    if svc.state == "crashed" then return "DiagnosticError" end
    if svc.state == "starting" then worst = "DiagnosticWarn" end
  end
  return worst or (#list() > 0 and "DiagnosticOk" or nil)
end

-- Nothing outlives the editor: quitting stops the servers.
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("config_services", { clear = true }),
  callback = function()
    for _, svc in ipairs(list()) do
      svc.stopping = true
      pcall(vim.fn.jobstop, svc.term.job_id)
    end
  end,
})

return M
