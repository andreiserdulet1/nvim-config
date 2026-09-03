-- GitHub Actions from the editor, via the `gh` CLI.
--
-- Watching and reading runs is safe and unguarded. Dispatching is not: this
-- repo's deploy.yml and rollback.yml both take an `environment` input whose
-- options include `prod`, so a keybind here can reach production. Anything
-- targeting prod requires typing the environment name; everything else gets a
-- plain confirmation. Neither is skippable.

local M = {}

---------------------------------------------------------------------------
-- Repo context
---------------------------------------------------------------------------

local function repo()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then dir = vim.uv.cwd() end
  local root = vim.fs.root(dir, ".git")
  if not root then return nil, "Not in a git repository" end
  return root
end

local function gh(args, cwd)
  return vim.system(vim.list_extend({ "gh" }, args), { cwd = cwd, text = true }):wait()
end

local function current_branch(root)
  local res = vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" },
    { cwd = root, text = true }):wait()
  return vim.trim(res.stdout or "") ~= "" and vim.trim(res.stdout) or "main"
end

---------------------------------------------------------------------------
-- Runs
---------------------------------------------------------------------------

local FIELDS = "databaseId,workflowName,displayTitle,status,conclusion,headBranch,createdAt,event"

local function fetch_runs(root, limit)
  local res = gh({ "run", "list", "--limit", tostring(limit or 20), "--json", FIELDS }, root)
  if res.code ~= 0 then
    return nil, vim.trim((res.stderr or "") .. (res.stdout or ""))
  end
  local ok, decoded = pcall(vim.json.decode, res.stdout, { luanil = { object = true } })
  if not ok or type(decoded) ~= "table" then return nil, "Could not parse gh output" end
  return decoded
end

local ICON = {
  success = "✓", failure = "✗", cancelled = "⊘",
  skipped = "–", startup_failure = "✗", timed_out = "⏱",
}

local function age(iso)
  local y, mo, d, h, mi = iso:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
  if not y then return "" end
  local then_ = os.time({ year = y, month = mo, day = d, hour = h, min = mi })
  local mins = math.floor((os.time() - then_) / 60)
  if mins < 60 then return mins .. "m ago" end
  if mins < 1440 then return math.floor(mins / 60) .. "h ago" end
  return math.floor(mins / 1440) .. "d ago"
end

local function label(run)
  local state = run.status == "completed" and (ICON[run.conclusion] or run.conclusion)
    or (run.status == "in_progress" and "●" or "○")
  return string.format("%s %-26s %-22s %-11s %s",
    state,
    (run.workflowName or ""):sub(1, 26),
    (run.headBranch or ""):sub(1, 22),
    age(run.createdAt or ""),
    (run.displayTitle or ""):sub(1, 46))
end

-- Read-only output into a scratch buffer, so it can be searched and yanked.
local function show_output(title, text, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = ft or "log"
  vim.bo[buf].bufhidden = "wipe"
  vim.cmd("botright vsplit")
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.wrap = false
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.api.nvim_buf_set_name(buf, "gh://" .. title)
end

local function in_terminal(cmd, root)
  require("toggleterm.terminal").Terminal
    :new({ cmd = cmd, dir = root, direction = "float", close_on_exit = false, hidden = true })
    :toggle()
end

--- Pick a run, then choose what to do with it.
function M.list()
  local root, err = repo()
  if not root then vim.notify(err, vim.log.levels.WARN) return end

  local runs, ferr = fetch_runs(root, 25)
  if not runs then vim.notify(ferr, vim.log.levels.ERROR) return end
  if #runs == 0 then vim.notify("No workflow runs in this repo") return end

  vim.ui.select(runs, {
    prompt = "Runs — " .. vim.fn.fnamemodify(root, ":t"),
    format_item = label,
  }, function(run)
    if not run then return end
    local actions = {
      { l = "Open the logs", f = function() M.logs(run.databaseId) end },
      { l = "Failed steps only", f = function() M.logs(run.databaseId, true) end },
      { l = "Watch it live", f = function() M.watch(run.databaseId) end },
      { l = "Re-run the failed jobs", f = function() M.rerun(run.databaseId) end },
      { l = "Open in the browser", f = function()
          gh({ "run", "view", tostring(run.databaseId), "--web" }, root)
        end },
    }
    vim.ui.select(actions, {
      prompt = tostring(run.workflowName) .. " #" .. tostring(run.databaseId),
      format_item = function(a) return a.l end,
    }, function(a) if a then a.f() end end)
  end)
end

--- Logs for a run, or for the latest run when no id is given.
function M.logs(id, failed_only)
  local root, err = repo()
  if not root then vim.notify(err, vim.log.levels.WARN) return end

  if not id then
    local runs = fetch_runs(root, 1)
    if not runs or #runs == 0 then vim.notify("No runs found") return end
    id = runs[1].databaseId
  end

  vim.notify("Fetching logs for run " .. id .. " …")
  local args = { "run", "view", tostring(id), failed_only and "--log-failed" or "--log" }
  local res = gh(args, root)
  local text = (res.stdout or "")
  if vim.trim(text) == "" then
    text = vim.trim((res.stderr or "")) 
    if text == "" then
      text = failed_only and "No failed steps in this run." or "No logs available."
    end
  end
  show_output((failed_only and "failed-" or "logs-") .. id, text)
end

--- Watch a run as it happens.
function M.watch(id)
  local root, err = repo()
  if not root then vim.notify(err, vim.log.levels.WARN) return end

  if not id then
    local runs = fetch_runs(root, 10)
    if not runs then vim.notify("Could not list runs", vim.log.levels.ERROR) return end
    for _, r in ipairs(runs) do
      if r.status ~= "completed" then id = r.databaseId break end
    end
    if not id then vim.notify("Nothing is running right now") return end
  end
  in_terminal("gh run watch " .. id, root)
end

--- Re-run just the failed jobs.
function M.rerun(id)
  local root, err = repo()
  if not root then vim.notify(err, vim.log.levels.WARN) return end

  if not id then
    local runs = fetch_runs(root, 25)
    if not runs then vim.notify("Could not list runs", vim.log.levels.ERROR) return end
    for _, r in ipairs(runs) do
      if r.conclusion == "failure" then id = r.databaseId break end
    end
    if not id then vim.notify("No failed run to re-run") return end
  end

  local res = gh({ "run", "rerun", tostring(id), "--failed" }, root)
  if res.code ~= 0 then
    vim.notify(vim.trim((res.stderr or "") .. (res.stdout or "")), vim.log.levels.ERROR)
  else
    vim.notify("Re-running failed jobs in " .. id)
  end
end

---------------------------------------------------------------------------
-- Dispatch
---------------------------------------------------------------------------

-- A deliberately small parser over workflow_dispatch.inputs. GitHub's API
-- doesn't expose dispatch inputs, and there's no YAML parser here, so this
-- reads the local file. It handles the shape these workflows use (name, then
-- description / required / type / options) and returns nil when it can't be
-- sure — in which case we hand off to `gh`, which prompts for inputs itself.
local function parse_dispatch(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end

  local in_dispatch, in_inputs, inputs, current = false, false, {}, nil
  local inputs_indent

  for _, raw in ipairs(lines) do
    local line = raw:gsub("%s+$", "")
    if line == "" or line:match("^%s*#") then goto continue end
    local indent = #(line:match("^(%s*)") or "")
    local body = vim.trim(line)

    if body:match("^workflow_dispatch:") then
      in_dispatch = true
      goto continue
    end

    if in_dispatch then
      -- A key at or left of "on:" level ends the dispatch block.
      if indent == 0 and not body:match("^workflow_dispatch") then break end

      if body:match("^inputs:") then
        in_inputs, inputs_indent = true, indent
        goto continue
      end

      if in_inputs then
        if indent <= inputs_indent and not body:match("^inputs:") then
          in_inputs = false
          goto continue
        end
        local name = body:match("^([%w_%-]+):$")
        if name and indent == inputs_indent + 2 then
          current = { name = name, type = "string", options = {} }
          table.insert(inputs, current)
        elseif current then
          local k, v = body:match("^([%w_]+):%s*(.+)$")
          if k == "type" then
            current.type = v:gsub("['\"]", "")
          elseif k == "description" then
            current.description = v:gsub("^['\"]", ""):gsub("['\"]$", "")
          elseif k == "required" then
            current.required = v == "true"
          elseif k == "default" then
            current.default = v:gsub("['\"]", "")
          end
          local opt = body:match("^%-%s*(.+)$")
          -- Parenthesised: gsub returns (string, count), and the bare call
          -- would pass that count as table.insert's position argument.
          if opt then table.insert(current.options, (vim.trim(opt):gsub("['\"]", ""))) end
        end
      end
    end
    ::continue::
  end

  return #inputs > 0 and inputs or (in_dispatch and {} or nil)
end

local function dispatchable(root)
  local dir = root .. "/.github/workflows"
  if vim.fn.isdirectory(dir) == 0 then return {} end
  local found = {}
  for name, t in vim.fs.dir(dir) do
    if t == "file" and (name:match("%.ya?ml$")) then
      local path = dir .. "/" .. name
      local inputs = parse_dispatch(path)
      if inputs then
        table.insert(found, { file = name, path = path, inputs = inputs })
      end
    end
  end
  table.sort(found, function(a, b) return a.file < b.file end)
  return found
end

-- The gate. Anything aimed at prod has to be typed out; everything else needs
-- one deliberate keypress. There is no path that dispatches on a single key.
local function confirm(summary, requires_typed, on_yes)
  local lines = { "" }
  for _, l in ipairs(summary) do table.insert(lines, "  " .. l) end
  table.insert(lines, "")

  if requires_typed then
    table.insert(lines, "  This targets " .. requires_typed:upper() .. ".")
    table.insert(lines, "")
    local buf_lines = lines
    local width = 0
    for _, l in ipairs(buf_lines) do width = math.max(width, vim.fn.strdisplaywidth(l)) end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, buf_lines)
    vim.bo[buf].modifiable = false
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor", width = math.max(width + 4, 50), height = #buf_lines,
      row = math.floor(vim.o.lines / 2) - #buf_lines, col = math.floor((vim.o.columns - width) / 2) - 2,
      style = "minimal", border = "rounded",
      title = " Confirm dispatch ", title_pos = "center",
    })
    vim.ui.input({ prompt = "Type " .. requires_typed .. " to confirm: " }, function(answer)
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      if answer == requires_typed then
        on_yes()
      else
        vim.notify("Cancelled — confirmation did not match", vim.log.levels.WARN)
      end
    end)
    return
  end

  local width = 0
  for _, l in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(l)) end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = math.max(width + 4, 50), height = #lines,
    row = math.floor((vim.o.lines - #lines) / 2), col = math.floor((vim.o.columns - width) / 2) - 2,
    style = "minimal", border = "rounded",
    title = " Dispatch?   [y] run   [q] cancel ", title_pos = "center",
  })
  local function close() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end
  for _, k in ipairs({ "y", "<CR>" }) do
    vim.keymap.set("n", k, function() close(); on_yes() end, { buffer = buf, nowait = true })
  end
  for _, k in ipairs({ "q", "<Esc>", "n" }) do
    vim.keymap.set("n", k, function() close(); vim.notify("Cancelled") end, { buffer = buf, nowait = true })
  end
end

--- Dispatch a workflow_dispatch workflow, with a confirmation you can't skip.
function M.dispatch()
  local root, err = repo()
  if not root then vim.notify(err, vim.log.levels.WARN) return end

  local workflows = dispatchable(root)
  if #workflows == 0 then
    vim.notify("No manually dispatchable workflows in this repo", vim.log.levels.WARN)
    return
  end

  vim.ui.select(workflows, {
    prompt = "Dispatch — " .. vim.fn.fnamemodify(root, ":t"),
    format_item = function(w)
      local n = #w.inputs
      return string.format("%-30s %s", w.file, n > 0 and (n .. " input(s)") or "no inputs")
    end,
  }, function(wf)
    if not wf then return end

    local branch = current_branch(root)
    local values = {}

    -- Collect inputs one at a time; vim.ui.select/input are async so this
    -- walks the list with a continuation rather than a loop.
    local function ask(i, done)
      local input = wf.inputs[i]
      if not input then done() return end

      local function next_(v)
        if v == nil or v == "" then
          vim.notify("Cancelled")
          return
        end
        values[input.name] = v
        ask(i + 1, done)
      end

      if input.type == "choice" and #input.options > 0 then
        vim.ui.select(input.options, {
          prompt = input.description or input.name,
        }, next_)
      elseif input.type == "boolean" then
        vim.ui.select({ "true", "false" }, { prompt = input.description or input.name }, next_)
      else
        vim.ui.input({
          prompt = (input.description or input.name) .. ": ",
          default = input.default,
        }, next_)
      end
    end

    ask(1, function()
      -- Header lines keep a fixed order; only the inputs are sorted, so the
      -- summary always reads workflow -> repo -> branch -> inputs.
      local width = 8
      for k in pairs(values) do width = math.max(width, #k) end
      local inputs_lines, prod_target = {}, nil
      for k, v in pairs(values) do
        table.insert(inputs_lines, string.format("%-" .. width .. "s : %s", k, v))
        if tostring(v):lower() == "prod" or tostring(v):lower() == "production" then
          prod_target = tostring(v):lower()
        end
      end
      table.sort(inputs_lines)

      local summary = {
        string.format("%-" .. width .. "s : %s", "workflow", wf.file),
        string.format("%-" .. width .. "s : %s", "repo", vim.fn.fnamemodify(root, ":t")),
        string.format("%-" .. width .. "s : %s", "branch", branch),
        "",
      }
      vim.list_extend(summary, inputs_lines)

      confirm(summary, prod_target, function()
        local args = { "workflow", "run", wf.file, "--ref", branch }
        for k, v in pairs(values) do
          table.insert(args, "-f")
          table.insert(args, k .. "=" .. v)
        end
        local res = gh(args, root)
        local out = vim.trim((res.stderr or "") .. (res.stdout or ""))
        if res.code ~= 0 then
          if out:match("HTTP 403") or out:lower():match("scope") then
            vim.notify("gh needs the workflow scope for this:\n"
              .. "  gh auth refresh -s workflow\n\n" .. out, vim.log.levels.ERROR)
          else
            vim.notify("Dispatch failed:\n" .. out, vim.log.levels.ERROR)
          end
          return
        end
        vim.notify("Dispatched " .. wf.file .. " on " .. branch .. " — <leader>Aw to watch")
      end)
    end)
  end)
end

return M
