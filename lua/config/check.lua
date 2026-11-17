-- Whole-project checks, in the background.
--
-- The language server only reports on files you have open, so a broken import
-- three folders away stays invisible until `ng build` or CI. <leader>cc runs,
-- side by side:
--
--   types   Angular's compiler (ngc) over tsconfig.app.json -- TypeScript AND
--           templates, the same strict checks `ng build` does -- plus tsc over
--           tsconfig.spec.json for the specs
--   lint    ESLint over src/
--
-- Problems land in the quickfix list (]q / [q walk it) and open in Trouble.
-- The statusline shows the result: ✓ checks, or ✗ 12.
--
-- Pre-push (see config/vcs.lua): <leader>gp runs these plus the headless test
-- suite first, and only pushes if everything passes. <leader>uP toggles it.

local M = {}

---@type { state: "running"|"ok"|"fail"|nil, count: integer }
M.status = { state = nil, count = 0 }
vim.g.check_before_push = true

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "checks" })
end

local function refresh()
  pcall(function() require("lualine").refresh() end)
end

local function root()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then dir = vim.uv.cwd() end
  return vim.fs.root(dir, ".git") or vim.fs.root(dir, "package.json")
end

local function bin(r, name)
  local p = r .. "/node_modules/.bin/" .. name
  return vim.fn.executable(p) == 1 and p or nil
end

---------------------------------------------------------------------------
-- Parsers
---------------------------------------------------------------------------

-- `file(line,col): error TS2304: msg` (plain), or
-- `file:line:col - error NG8002: msg` (pretty).
local function parse_ts(r, text)
  local items = {}
  local clean = text:gsub("\27%[[%d;]*m", "")
  for line in clean:gmatch("[^\n]+") do
    local f, l, c, sev, code, msg = line:match("^(.-)%((%d+),(%d+)%): (%a+) (%w+): (.*)$")
    if not f then f, l, c, sev, code, msg = line:match("^(.-):(%d+):(%d+) %- (%a+) (%w+): (.*)$") end
    if f and (sev == "error" or sev == "warning") then
      table.insert(items, {
        filename = f:sub(1, 1) == "/" and f or (r .. "/" .. f),
        lnum = tonumber(l), col = tonumber(c),
        type = sev == "error" and "E" or "W",
        text = code .. ": " .. msg,
      })
    elseif #items > 0 and line:match("^%s%s+%S") and not line:match("^%s+%d+ ")
      and not line:match("^[%s~]+$") then
      -- Continuation lines of a multi-line message.
      items[#items].text = items[#items].text .. " " .. vim.trim(line)
    end
  end
  return items
end

local function parse_eslint(text)
  local ok, files = pcall(vim.json.decode, text)
  if not ok or type(files) ~= "table" then return nil end
  local items = {}
  for _, file in ipairs(files) do
    for _, m in ipairs(file.messages or {}) do
      table.insert(items, {
        filename = file.filePath,
        lnum = m.line or 1, col = m.column or 1,
        type = m.severity == 2 and "E" or "W",
        text = (m.ruleId and (m.ruleId .. ": ") or "") .. m.message,
      })
    end
  end
  return items
end

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------

-- Start every job, collect each one's problems, call done(items, failed_jobs).
local function run_jobs(jobs, done)
  local pending, items, failed = #jobs, {}, {}
  if pending == 0 then done(items, failed) return end
  for _, job in ipairs(jobs) do
    vim.system(job.cmd, { cwd = job.cwd, text = true, env = job.env }, function(res)
      vim.schedule(function()
        local found = job.parse(res) or {}
        vim.list_extend(items, found)
        if res.code ~= 0 then
          table.insert(failed, { name = job.name, count = #found,
            output = (res.stdout or "") .. "\n" .. (res.stderr or "") })
        end
        pending = pending - 1
        if pending == 0 then done(items, failed) end
      end)
    end)
  end
end

local function jobs_for(r, opts)
  local jobs = {}
  local ngc, tsc, eslint = bin(r, "ngc"), bin(r, "tsc"), bin(r, "eslint")
  if opts.types ~= false then
    if ngc and vim.uv.fs_stat(r .. "/tsconfig.app.json") then
      table.insert(jobs, { name = "types (app + templates)", cwd = r,
        cmd = { ngc, "-p", "tsconfig.app.json", "--noEmit" },
        parse = function(res) return parse_ts(r, (res.stdout or "") .. (res.stderr or "")) end })
    elseif tsc then
      table.insert(jobs, { name = "types", cwd = r, cmd = { tsc, "--noEmit", "--pretty", "false" },
        parse = function(res) return parse_ts(r, (res.stdout or "") .. (res.stderr or "")) end })
    end
    if tsc and vim.uv.fs_stat(r .. "/tsconfig.spec.json") then
      table.insert(jobs, { name = "types (specs)", cwd = r,
        cmd = { tsc, "-p", "tsconfig.spec.json", "--noEmit", "--pretty", "false" },
        parse = function(res) return parse_ts(r, (res.stdout or "") .. (res.stderr or "")) end })
    end
  end
  if opts.lint ~= false and eslint then
    table.insert(jobs, { name = "lint", cwd = r,
      cmd = { eslint, vim.uv.fs_stat(r .. "/src") and "src" or ".", "--format", "json" },
      parse = function(res) return parse_eslint(res.stdout or "") end })
  end
  if opts.tests then
    local scripts = require("config.scripts")
    local proj = scripts.decode(r .. "/package.json")
    local script, needs_no_watch = proj and scripts.test_script(proj.scripts)
    if script then
      local cmd = { "yarn", script }
      if needs_no_watch then table.insert(cmd, "--watch=false") end
      if vim.fn.executable("direnv") == 1 and vim.uv.fs_stat(r .. "/.envrc") then
        cmd = vim.list_extend({ "direnv", "exec", "." }, cmd)
      end
      table.insert(jobs, { name = "tests", cwd = r, cmd = cmd, parse = function() return {} end })
    end
  end
  return jobs
end

--- Run the checks for the current project.
---@param opts { types: boolean?, lint: boolean?, tests: boolean?, quiet: boolean? }|nil
---@param done fun(ok: boolean, items: table[], failed: table[])|nil
function M.run(opts, done)
  opts = opts or {}
  local r = root()
  if not r then notify("Not in a project", vim.log.levels.WARN) return end
  local jobs = jobs_for(r, opts)
  if #jobs == 0 then
    notify("No ngc / tsc / eslint in node_modules — run yarn install", vim.log.levels.WARN)
    return
  end
  if M.status.state == "running" then notify("Checks are already running") return end

  -- Checks read the files on disk; make sure that is what you are looking at.
  pcall(vim.cmd, "silent! wall")
  M.status = { state = "running", count = 0 }
  refresh()
  local names = vim.tbl_map(function(j) return j.name end, jobs)
  local started = vim.uv.hrtime()
  notify("Checking " .. vim.fs.basename(r) .. ": " .. table.concat(names, ", ") .. " …")

  run_jobs(jobs, function(items, failed)
    local secs = math.floor((vim.uv.hrtime() - started) / 1e9)
    local errors = #vim.tbl_filter(function(i) return i.type == "E" end, items)
    -- A job can fail without anything parseable (a crashed test run, a bad
    -- tsconfig); that is a failure too.
    local unexplained = vim.tbl_filter(function(f) return f.count == 0 end, failed)
    local ok = errors == 0 and #unexplained == 0
    M.status = { state = ok and "ok" or "fail", count = errors + #unexplained }
    M.last_failed = failed
    refresh()

    vim.fn.setqflist({}, " ", { title = "checks: " .. vim.fs.basename(r), items = items })
    if ok then
      local warns = #items
      notify(("✓ %s in %ds%s"):format(table.concat(names, ", "), secs,
        warns > 0 and (" — " .. warns .. " warning(s) in the quickfix list") or ""))
    else
      local parts = {}
      for _, f in ipairs(failed) do
        table.insert(parts, f.name .. (f.count > 0 and (" (" .. f.count .. ")") or " (see output)"))
      end
      notify(("✗ %d problem(s) — %s"):format(errors + #unexplained, table.concat(parts, ", ")),
        vim.log.levels.ERROR)
      if not opts.quiet and #items > 0 then pcall(vim.cmd, "Trouble qflist open") end
      for _, f in ipairs(unexplained) do
        require("config.scratch").open("check-" .. f.name:gsub("%W", ""), f.output, { scheme = "check" })
      end
    end
    if done then done(ok, items, failed) end
  end)
end

function M.all() M.run({}) end
function M.types() M.run({ lint = false }) end
function M.lint() M.run({ types = false }) end

function M.toggle_pre_push()
  vim.g.check_before_push = not vim.g.check_before_push
  notify("Checks before push: " .. (vim.g.check_before_push and "on (types, lint, tests)" or "off"))
end

--- Statusline: nothing until the first run, then ⟳ / ✓ / ✗ n.
function M.statusline()
  local s = M.status
  if s.state == "running" then return "⟳ checks" end
  if s.state == "ok" then return "✓ checks" end
  if s.state == "fail" then return "✗ " .. s.count end
  return ""
end

function M.statusline_hl()
  local s = M.status.state
  return s == "ok" and "DiagnosticOk" or (s == "fail" and "DiagnosticError" or (s == "running" and "DiagnosticWarn" or nil))
end

return M
