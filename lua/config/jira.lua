-- Jira from the editor, via the `jira` CLI (ankitpokhrel/jira-cli).
--
-- Same division of labour as config/actions.lua: the CLI owns authentication,
-- JQL and the REST API, this file owns presentation. There is no HTTP code
-- here and no pagination to get wrong.
--
-- Credentials
-- -----------
-- The API token lives in the macOS Keychain. It is read once per session and
-- injected into the environment of the `jira` process alone -- it is never put
-- into vim.env, so it cannot leak into a :terminal, into another plugin, or
-- into any other child process this config spawns.
--
-- The Keychain *account* is read from jira-cli's own config file rather than
-- written here, so this file contains no email address, no site URL and no
-- token. That matters: this repo is public.

local M = {}

local SERVICE = "jira-api-token"
local CONFIG = vim.fn.expand("~/.config/.jira/.config.yml")

M.SERVICE = SERVICE
M.CONFIG = CONFIG

---------------------------------------------------------------------------
-- Credentials
---------------------------------------------------------------------------

-- `login:` out of ~/.config/.jira/.config.yml. A three-line reader beats a YAML
-- parser for one top-level scalar, and jira-cli writes this file itself.
local login_cache
function M.login()
  if login_cache then return login_cache end
  if vim.fn.filereadable(CONFIG) == 0 then return nil end
  local ok, lines = pcall(vim.fn.readfile, CONFIG)
  if not ok then return nil end
  for _, line in ipairs(lines) do
    local value = line:match("^login:%s*(.+)$")
    if value then
      login_cache = (vim.trim(value):gsub("^['\"]", ""):gsub("['\"]$", ""))
      return login_cache
    end
  end
  return nil
end

--- How to fix a missing credential, as one message the reader can act on.
local function setup_hint(account)
  return table.concat({
    "  security add-generic-password -s " .. SERVICE
      .. " -a " .. (account or "<your jira login>") .. " -U -w",
    "",
    "It prompts for the token without echoing it. See the Jira section of the README.",
  }, "\n")
end

local token_cache
local function token()
  if token_cache then return token_cache end

  local account = M.login()
  if not account then
    return nil, "jira-cli is not configured yet — run `jira init`.\n"
      .. "Expected a `login:` line in " .. vim.fn.fnamemodify(CONFIG, ":~")
  end

  local res = vim.system(
    { "security", "find-generic-password", "-s", SERVICE, "-a", account, "-w" },
    { text = true }
  ):wait()

  local value = vim.trim(res.stdout or "")
  if res.code ~= 0 or value == "" then
    return nil, "No Jira API token in the Keychain for " .. account .. ".\n\n" .. setup_hint(account)
  end

  token_cache = value
  return token_cache
end

--- Forget the cached token, for when you have just rotated it.
function M.forget()
  token_cache, login_cache = nil, nil
  vim.notify("Jira token forgotten; it will be re-read from the Keychain")
end

---------------------------------------------------------------------------
-- Running the CLI
---------------------------------------------------------------------------

--- Run `jira` and return stdout, or nil plus a message worth showing.
---@param args string[]
---@param opts table|nil  { stdin = string }
local function jira(args, opts)
  opts = opts or {}
  if vim.fn.executable("jira") == 0 then
    return nil, "jira-cli is not installed — brew bundle --file=~/.config/nvim/Brewfile"
  end

  local tok, err = token()
  if not tok then return nil, err end

  local res = vim.system(vim.list_extend({ "jira" }, args), {
    text = true,
    stdin = opts.stdin,
    -- Merged into the inherited environment: clear_env defaults to false, so
    -- PATH and everything else the CLI needs still reaches it.
    env = { JIRA_API_TOKEN = tok },
  }):wait()

  if res.code ~= 0 then
    local out = vim.trim((res.stderr or "") .. "\n" .. (res.stdout or ""))
    if out:match("401") or out:lower():match("unauthor") then
      out = out .. "\n\nThe token was rejected. If you rotated it, re-add it:\n\n"
        .. setup_hint(M.login())
    end
    return nil, out
  end
  return res.stdout or ""
end

-- Interactive subcommands go to a float rather than vim.system, and need the
-- token in the job's environment the same way.
local function in_terminal(cmd)
  local tok, err = token()
  if not tok then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  require("toggleterm.terminal").Terminal
    :new({
      cmd = cmd,
      direction = "float",
      close_on_exit = false,
      hidden = true,
      env = { JIRA_API_TOKEN = tok },
    })
    :toggle()
end

---------------------------------------------------------------------------
-- Reading issues
---------------------------------------------------------------------------

-- --raw rather than --plain --columns: the plain formatter truncates to the
-- terminal width and its column order is its own business, whereas the raw
-- API response is stable and already the shape we want.
local function decode(out)
  local ok, body = pcall(vim.json.decode, out, { luanil = { object = true } })
  if not ok or type(body) ~= "table" then return nil, "Could not parse the jira response" end

  local raw = body.issues or (vim.islist(body) and body) or nil
  if type(raw) ~= "table" then return nil, "No issues in the jira response" end

  local issues = {}
  for _, it in ipairs(raw) do
    local f = it.fields or {}
    table.insert(issues, {
      key = it.key,
      summary = f.summary or "",
      status = (f.status and f.status.name) or "",
      assignee = (f.assignee and (f.assignee.displayName or f.assignee.emailAddress)) or "Unassigned",
      type = (f.issuetype and f.issuetype.name) or "",
    })
  end
  return issues
end

local function fetch(args)
  local out, err = jira(args)
  if not out then return nil, err end
  return decode(out)
end

--- Issues in the board's current sprint.
---
--- Via `issue list`, not `sprint list --current`: the latter ignores --raw and
--- prints its plain table anyway, which is not something to parse. The JQL
--- returns exactly the same set -- jira-cli scopes -q to the configured
--- project, and openSprints() to the sprints currently running in it.
function M.sprint_issues()
  return fetch({ "issue", "list", "-q", "sprint in openSprints()", "--raw" })
end

--- Your own issues that aren't done yet. `jira me` prints the same login that
--- M.login() reads out of the config file, so there is no second call to make.
function M.my_issues()
  local me = M.login()
  if not me then return nil, "jira-cli is not configured yet — run `jira init`" end
  return fetch({ "issue", "list", "-a", me, "-s~Done", "--raw" })
end

--- Anything matching a JQL fragment.
function M.jql_issues(jql) return fetch({ "issue", "list", "-q", jql, "--raw" }) end

---------------------------------------------------------------------------
-- The issue you are probably talking about
---------------------------------------------------------------------------

local KEY_PATTERN = "%u[%u%d]*%-%d+"

local function branch_key()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then dir = vim.uv.cwd() end
  local root = vim.fs.root(dir, ".git")
  if not root then return nil end
  local res = vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" },
    { cwd = root, text = true }):wait()
  return vim.trim(res.stdout or ""):match(KEY_PATTERN)
end

--- Resolve the issue in play: this branch's, else the one under the cursor,
--- else ask. Async, because the last case has to prompt.
---@param callback fun(key: string)
function M.current(callback)
  local key = branch_key()
  if key then callback(key) return end

  local word = vim.fn.expand("<cWORD>"):match(KEY_PATTERN)
  if word then callback(word) return end

  vim.ui.input({ prompt = "Issue key: " }, function(answer)
    answer = answer and vim.trim(answer):upper() or ""
    if answer:match("^" .. KEY_PATTERN .. "$") then
      callback(answer)
    elseif answer ~= "" then
      vim.notify(answer .. " is not an issue key", vim.log.levels.WARN)
    end
  end)
end

---------------------------------------------------------------------------
-- Acting on an issue
---------------------------------------------------------------------------

-- Read-only output into a scratch buffer so it can be searched and yanked.
-- Same shape as config/actions.lua's show_output.
local function show(name, text, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = ft or "markdown"
  vim.bo[buf].bufhidden = "wipe"
  vim.cmd("botright vsplit")
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.wrap = true
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  pcall(vim.api.nvim_buf_set_name, buf, "jira://" .. name)
end

local function fail(err) vim.notify(err, vim.log.levels.ERROR) end

--- Render an issue, description and latest comments included.
function M.view(key)
  local out, err = jira({ "issue", "view", key, "--plain", "--comments", "10" })
  if not out then fail(err) return end
  show(key, out)
end

--- Open the issue in a browser.
function M.open(key)
  local out, err = jira({ "open", key })
  if not out then fail(err) return end
  vim.notify("Opened " .. key)
end

-- Everything the board can be in, taken from the sprint itself. Deriving the
-- column set from the data means no Awin status names are hardcoded here, and
-- a board that gains a column keeps working.
local function sprint_statuses()
  local issues = M.sprint_issues()
  local seen, out = {}, {}
  for _, i in ipairs(issues or {}) do
    if i.status ~= "" and not seen[i.status] then
      seen[i.status] = true
      table.insert(out, i.status)
    end
  end
  table.sort(out)
  return out
end

--- Transition an issue to another column.
function M.move(key)
  local choices = sprint_statuses()
  table.insert(choices, "Other…")

  vim.ui.select(choices, { prompt = "Move " .. key .. " to" }, function(choice)
    if not choice then return end

    local function go(status)
      if not status or vim.trim(status) == "" then return end
      local out, err = jira({ "issue", "move", key, status })
      if not out then fail(err) return end
      vim.notify(key .. " → " .. status)
    end

    if choice == "Other…" then
      -- The sprint only shows the columns currently in use, so a status nobody
      -- is sitting in has to be typed. jira-cli rejects an invalid one.
      vim.ui.input({ prompt = "Status: " }, go)
    else
      go(choice)
    end
  end)
end

--- Assign an issue.
function M.assign(key)
  local me = M.login()
  local issues = M.sprint_issues() or {}

  local seen, people = {}, {}
  for _, i in ipairs(issues) do
    if i.assignee ~= "" and i.assignee ~= "Unassigned" and not seen[i.assignee] then
      seen[i.assignee] = true
      table.insert(people, i.assignee)
    end
  end
  table.sort(people)

  -- "x" is jira-cli's unassign sentinel; everyone else is matched by exact
  -- display name or email, which is why the list comes from real issues.
  local choices = { { label = "Me (" .. (me or "?") .. ")", value = me }, { label = "Unassign", value = "x" } }
  for _, p in ipairs(people) do table.insert(choices, { label = p, value = p }) end
  table.insert(choices, { label = "Someone else…", value = nil })

  vim.ui.select(choices, {
    prompt = "Assign " .. key .. " to",
    format_item = function(c) return c.label end,
  }, function(choice)
    if not choice then return end

    local function go(who)
      if not who or vim.trim(who) == "" then return end
      local out, err = jira({ "issue", "assign", key, who })
      if not out then fail(err) return end
      vim.notify(key .. " assigned to " .. who)
    end

    if choice.value then
      go(choice.value)
    else
      vim.ui.input({ prompt = "Email or exact display name: " }, go)
    end
  end)
end

--- Write a comment in a real buffer, then post it with <C-s>.
---
--- Deliberately not `jira issue comment add` with no body: that opens $EDITOR,
--- which is nvim, inside a terminal, inside nvim.
function M.comment(key)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "", "", "<!-- " .. key .. " — <C-s> posts this comment, q discards it -->",
  })
  pcall(vim.api.nvim_buf_set_name, buf, "jira://comment/" .. key)

  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_height(0, 12)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("startinsert")

  local function post()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local body = {}
    for _, l in ipairs(lines) do
      if not l:match("^<!%-%-") then table.insert(body, l) end
    end
    local text = vim.trim(table.concat(body, "\n"))
    if text == "" then
      vim.notify("Nothing to post", vim.log.levels.WARN)
      return
    end
    -- --template - reads the body from stdin, so the comment never touches
    -- disk and there is no temp file to clean up.
    local out, err = jira({ "issue", "comment", "add", key, "--no-input", "--template", "-" },
      { stdin = text })
    if not out then fail(err) return end
    vim.cmd("close")
    vim.notify("Commented on " .. key)
  end

  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    vim.cmd("stopinsert")
    post()
  end, { buffer = buf })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
end

---------------------------------------------------------------------------
-- The picker
---------------------------------------------------------------------------

-- This is the one place in the config that builds a Telescope picker by hand
-- rather than going through vim.ui.select. The point of the Jira layer is
-- acting on an issue without leaving the list, and per-entry mappings are the
-- only way to get that.

local STATUS_ICON = {
  ["to do"] = "○", ["open"] = "○", ["backlog"] = "○",
  ["in progress"] = "◐", ["in development"] = "◐",
  ["in review"] = "◑", ["code review"] = "◑", ["in testing"] = "◑",
  ["done"] = "●", ["closed"] = "●", ["resolved"] = "●",
}

local function entry(issue)
  local icon = STATUS_ICON[issue.status:lower()] or "◇"
  return string.format("%s %-12s %-14s %-18s %s",
    icon,
    issue.key,
    issue.status:sub(1, 14),
    issue.assignee:sub(1, 18),
    issue.summary)
end

--- Everything you can do to the issue under the cursor, as a menu. Keeps every
--- action reachable without memorising the control keys below.
local function menu(key)
  local actions = {
    { l = "View", f = function() M.view(key) end },
    { l = "Move to another column", f = function() M.move(key) end },
    { l = "Assign", f = function() M.assign(key) end },
    { l = "Comment", f = function() M.comment(key) end },
    { l = "Open in the browser", f = function() M.open(key) end },
  }
  vim.ui.select(actions, { prompt = key, format_item = function(a) return a.l end },
    function(a) if a then a.f() end end)
end

--- Show a list of issues, with the actions bound to control keys.
---@param title string
---@param issues table[]
function M.pick(title, issues)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")

  local function selected()
    local sel = state.get_selected_entry()
    return sel and sel.value or nil
  end

  -- Close the picker first: every action either prompts or opens a window, and
  -- both fight with a picker that is still up.
  local function act(fn)
    return function(bufnr)
      local issue = selected()
      if not issue then return end
      actions.close(bufnr)
      vim.schedule(function() fn(issue.key) end)
    end
  end

  pickers.new({}, {
    prompt_title = title .. "   <CR> actions  ^t move  ^a assign  ^c comment  ^o browser",
    finder = finders.new_table({
      results = issues,
      entry_maker = function(issue)
        return {
          value = issue,
          display = entry(issue),
          -- Searchable on key, status, assignee and summary together, so
          -- "1841", "review" and "rounding" all find the same issue.
          ordinal = table.concat({ issue.key, issue.status, issue.assignee, issue.summary }, " "),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(_, map)
      actions.select_default:replace(act(menu))
      for _, mode in ipairs({ "i", "n" }) do
        map(mode, "<C-t>", act(M.move))
        map(mode, "<C-a>", act(M.assign))
        map(mode, "<C-c>", act(M.comment))
        map(mode, "<C-o>", act(M.open))
        map(mode, "<C-v>", act(M.view))
      end
      return true
    end,
  }):find()
end

-- Fetch, complain usefully if that fails, then show.
local function show_list(title, fetcher)
  local issues, err = fetcher()
  if not issues then fail(err) return end
  if #issues == 0 then
    vim.notify("No issues in " .. title, vim.log.levels.WARN)
    return
  end
  M.pick(title, issues)
end

--- Issues in the current sprint.
function M.sprint() show_list("Current sprint", M.sprint_issues) end

--- Your open issues.
function M.mine() show_list("My open issues", M.my_issues) end

--- Pick a column first, then an issue in it. The columns come from the sprint,
--- so they are the board's real columns rather than a hardcoded list.
function M.board()
  local issues, err = M.sprint_issues()
  if not issues then fail(err) return end
  if #issues == 0 then vim.notify("Nothing in the current sprint") return end

  local order, by_status = {}, {}
  for _, i in ipairs(issues) do
    if not by_status[i.status] then
      by_status[i.status] = {}
      table.insert(order, i.status)
    end
    table.insert(by_status[i.status], i)
  end
  table.sort(order)

  vim.ui.select(order, {
    prompt = "Board — pick a column",
    format_item = function(s) return string.format("%-24s %d", s, #by_status[s]) end,
  }, function(status)
    if status then M.pick(status, by_status[status]) end
  end)
end

--- Free-text search across the project.
function M.search()
  vim.ui.input({ prompt = "Search issues: " }, function(text)
    if not text or vim.trim(text) == "" then return end
    -- Quotes would terminate the JQL string early and change the query.
    local safe = text:gsub('"', "")
    local jql = string.format('summary ~ "%s" OR description ~ "%s" ORDER BY updated DESC', safe, safe)
    show_list("Search: " .. text, function() return M.jql_issues(jql) end)
  end)
end

--- The raw jira-cli explorer, for anything this layer does not wrap.
function M.tui()
  in_terminal("jira sprint list --current")
end

return M
