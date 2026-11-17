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

-- `key:` out of the same file, one level deeper: jira-cli writes it indented
-- under `project:`. Same reasoning as M.login() -- this is two scalars out of a
-- file jira-cli owns, not a reason to take a YAML parser as a dependency.
local project_cache
function M.project()
  if project_cache then return project_cache end
  if vim.fn.filereadable(CONFIG) == 0 then return nil end
  local ok, lines = pcall(vim.fn.readfile, CONFIG)
  if not ok then return nil end
  local inside = false
  for _, line in ipairs(lines) do
    if line:match("^project:") then
      inside = true
    elseif inside then
      local value = line:match("^%s+key:%s*(.+)$")
      if value then
        project_cache = (vim.trim(value):gsub("^['\"]", ""):gsub("['\"]$", ""):upper())
        return project_cache
      end
      -- An unindented line means the project block is over.
      if line:match("^%S") then inside = false end
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
  token_cache, login_cache, project_cache = nil, nil, nil
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

--- Read a string as an issue key, if that is what it is.
---
--- Accepts "AR-991", "ar-991", "#991" and a bare "991" -- the last two resolved
--- against the project jira-cli is configured for, because typing the prefix
--- you always type is the part worth dropping.
---@return string|nil key
local function as_key(text)
  text = vim.trim(text or ""):upper()
  if text:match("^" .. KEY_PATTERN .. "$") then return text end
  local number = text:match("^#?(%d+)$")
  if number then
    local project = M.project()
    if project then return project .. "-" .. number end
  end
  return nil
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
    local resolved = as_key(answer)
    if resolved then
      callback(resolved)
    elseif answer and vim.trim(answer) ~= "" then
      vim.notify(vim.trim(answer) .. " is not an issue key", vim.log.levels.WARN)
    end
  end)
end

---------------------------------------------------------------------------
-- Acting on an issue
---------------------------------------------------------------------------

-- Read-only output into a scratch buffer so it can be searched and yanked.
local function show(name, text, ft)
  require("config.scratch").open(name, text,
    { scheme = "jira", filetype = ft or "markdown", wrap = true })
end

local function fail(err) vim.notify(err, vim.log.levels.ERROR) end

---------------------------------------------------------------------------
-- Reading an issue
---------------------------------------------------------------------------

-- Jira Cloud stores descriptions and comments as ADF -- Atlassian Document
-- Format, a nested JSON tree -- not as text or markdown.
--
-- `jira issue view --plain` renders that for a terminal, which was the first
-- implementation here. Two things were wrong with it in a buffer: it pads
-- every line out to a fixed 118 columns, so a narrow split reads badly and the
-- text can never re-wrap; and it omits the fields that actually matter on a
-- board -- sprint, story points, epic. Both come from rendering ADF directly.
--
-- The node set Jira actually emits is small. Anything unrecognised recurses
-- into its children rather than being dropped, so a node type not handled here
-- still surfaces its text.

--- Inline nodes: text plus its marks, mentions, emoji, links.
local function adf_inline(node)
  local t = node.type

  if t == "text" then
    local text = node.text or ""
    for _, m in ipairs(node.marks or {}) do
      local mt = m.type
      if mt == "strong" then text = "**" .. text .. "**"
      elseif mt == "em" then text = "*" .. text .. "*"
      elseif mt == "code" then text = "`" .. text .. "`"
      elseif mt == "strike" then text = "~~" .. text .. "~~"
      elseif mt == "link" and m.attrs and m.attrs.href then
        text = "[" .. text .. "](" .. m.attrs.href .. ")"
      end
    end
    return text
  elseif t == "hardBreak" then
    return "\n"
  elseif t == "mention" then
    local name = (node.attrs and (node.attrs.text or node.attrs.displayName)) or "someone"
    return "@" .. (name:gsub("^@", ""))
  elseif t == "emoji" then
    return (node.attrs and (node.attrs.text or node.attrs.shortName)) or ""
  elseif t == "inlineCard" then
    return (node.attrs and node.attrs.url) or ""
  end

  local parts = {}
  for _, c in ipairs(node.content or {}) do table.insert(parts, adf_inline(c)) end
  return table.concat(parts)
end

--- Block nodes, appending markdown lines.
local function adf_blocks(node, lines, prefix)
  prefix = prefix or ""
  local t = node.type

  local function inline_of(n)
    local parts, prev = {}, nil
    for _, c in ipairs(n.content or {}) do
      local piece = adf_inline(c)
      -- Jira does not always store a space between a mention and the word
      -- after it, which renders as "@Zohreh Hassaniplease take a look".
      if prev == "mention" and piece:match("^[%w]") then piece = " " .. piece end
      table.insert(parts, piece)
      prev = c.type
    end
    return table.concat(parts)
  end

  if t == "paragraph" then
    local text = inline_of(node)
    -- hardBreak came back as a newline; split so each becomes its own line.
    for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
      table.insert(lines, prefix .. l)
    end
    table.insert(lines, "")
  elseif t == "heading" then
    -- Shifted down two levels: the issue summary is the document's H1.
    local level = math.min(((node.attrs and node.attrs.level) or 1) + 2, 6)
    table.insert(lines, prefix .. string.rep("#", level) .. " " .. inline_of(node))
    table.insert(lines, "")
  elseif t == "bulletList" or t == "orderedList" then
    local n = 1
    for _, item in ipairs(node.content or {}) do
      local marker = t == "bulletList" and "- " or (n .. ". ")
      local sub = {}
      for _, c in ipairs(item.content or {}) do adf_blocks(c, sub, "") end
      while #sub > 0 and sub[#sub] == "" do table.remove(sub) end
      for i, l in ipairs(sub) do
        -- An empty continuation line must stay empty; indenting it would leave
        -- trailing whitespace in the middle of a list.
        if l == "" then
          table.insert(lines, "")
        else
          table.insert(lines, prefix .. (i == 1 and marker or string.rep(" ", #marker)) .. l)
        end
      end
      n = n + 1
    end
    table.insert(lines, "")
  elseif t == "codeBlock" then
    table.insert(lines, prefix .. "```" .. ((node.attrs and node.attrs.language) or ""))
    for _, c in ipairs(node.content or {}) do
      for _, l in ipairs(vim.split(c.text or "", "\n", { plain = true })) do
        table.insert(lines, prefix .. l)
      end
    end
    table.insert(lines, prefix .. "```")
    table.insert(lines, "")
  elseif t == "blockquote" then
    local sub = {}
    for _, c in ipairs(node.content or {}) do adf_blocks(c, sub, "") end
    while #sub > 0 and sub[#sub] == "" do table.remove(sub) end
    for _, l in ipairs(sub) do table.insert(lines, prefix .. "> " .. l) end
    table.insert(lines, "")
  elseif t == "rule" then
    table.insert(lines, prefix .. "---")
    table.insert(lines, "")
  elseif t == "mediaSingle" or t == "mediaGroup" then
    table.insert(lines, prefix .. "_[attachment]_")
    table.insert(lines, "")
  else
    -- doc, table, and anything Atlassian adds later: keep walking so the text
    -- inside is never silently lost.
    for _, c in ipairs(node.content or {}) do adf_blocks(c, lines, prefix) end
  end
end

--- Render an ADF document to markdown lines.
---@param doc table|nil
---@return string[]
function M.adf(doc)
  if type(doc) ~= "table" then return {} end
  local lines = {}
  adf_blocks(doc, lines, "")
  for i, l in ipairs(lines) do lines[i] = (l:gsub("%s+$", "")) end
  while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
  return lines
end

-- Custom field ids differ per Jira instance, so they are resolved by NAME from
-- jira-cli's own config rather than hardcoded -- which also keeps this repo
-- free of one more Awin-specific number. Several projects here declare fields
-- with the same name, hence a list of candidate ids per name and "first one
-- that is actually set on this issue wins".
local custom_fields_cache

local function custom_fields()
  if custom_fields_cache then return custom_fields_cache end

  local ok, lines = pcall(vim.fn.readfile, CONFIG)
  -- Deliberately not cached on failure. readfile can fail for a reason that
  -- goes away -- being called from the wrong context, say -- and caching the
  -- empty result would silently drop Sprint and points for the whole session.
  if not ok then return {} end

  local map = {}
  local pending
  for _, line in ipairs(lines) do
    local name = line:match("^%s*%-?%s*name:%s*(.+)$")
    local field = line:match("^%s*key:%s*(customfield_%d+)%s*$")
    if name then
      pending = vim.trim(name):gsub("^['\"]", ""):gsub("['\"]$", "")
    elseif field and pending then
      local lower = pending:lower()
      map[lower] = map[lower] or {}
      table.insert(map[lower], field)
      pending = nil
    end
  end

  custom_fields_cache = map
  return map
end

--- First non-nil value among the fields registered under any of `names`.
local function custom(fields, names)
  local map = custom_fields()
  for _, name in ipairs(names) do
    for _, id in ipairs(map[name:lower()] or {}) do
      if fields[id] ~= nil then return fields[id] end
    end
  end
  return nil
end

local function short_date(iso)
  local y, mo, d = tostring(iso):match("(%d+)-(%d+)-(%d+)")
  if not y then return "" end
  return os.date("%d %b %Y", os.time({ year = y, month = mo, day = d, hour = 12 }))
end

--- Everything about an issue, as markdown lines.
---
--- Split from the fetch so the picker's previewer can render an async response
--- through exactly the same code as <leader>jv, rather than a second, subtly
--- different renderer that drifts.
---@param out string  the raw JSON of one issue
---@return string[]|nil lines
function M.detail_from_json(out)
  local ok, issue = pcall(vim.json.decode, out, { luanil = { object = true } })
  if not ok or type(issue) ~= "table" or not issue.fields then return nil end
  local f = issue.fields
  local key = issue.key or ""

  local function name_of(v) return type(v) == "table" and (v.name or v.displayName) or nil end

  -- Sprint is an array of sprint objects; the one you care about is the last,
  -- since a carried-over issue lists every sprint it has been in.
  local sprints = custom(f, { "Sprint" })
  local sprint
  if type(sprints) == "table" and #sprints > 0 then
    sprint = name_of(sprints[#sprints]) or tostring(sprints[#sprints])
  end

  local points = custom(f, { "Story Points", "Story point estimate", "Story points" })
  local epic_key = custom(f, { "Epic Link" })
  local parent = f.parent

  local lines = {
    "# " .. key .. " · " .. (f.summary or ""),
    "",
  }

  -- One dense status line, then the rest as a label/value block.
  local badge = {}
  for _, v in ipairs({
    name_of(f.issuetype), name_of(f.status), name_of(f.priority),
    points and (tostring(points):gsub("%.0$", "") .. " points") or nil,
  }) do
    if v and v ~= "" then table.insert(badge, v) end
  end
  table.insert(lines, "`" .. table.concat(badge, "`  `") .. "`")
  table.insert(lines, "")

  local function row(label, value)
    if value and value ~= "" then
      table.insert(lines, string.format("%-10s %s", label, value))
    end
  end

  row("Sprint", sprint)
  if parent then
    row("Epic", (parent.key or "") .. "  " .. ((parent.fields and parent.fields.summary) or ""))
  elseif epic_key then
    row("Epic", epic_key)
  end
  row("Assignee", name_of(f.assignee) or "Unassigned")
  row("Reporter", name_of(f.reporter))
  row("Created", short_date(f.created))
  row("Updated", short_date(f.updated))
  if f.labels and #f.labels > 0 then row("Labels", table.concat(f.labels, ", ")) end
  if f.components and #f.components > 0 then
    local names = {}
    for _, c in ipairs(f.components) do table.insert(names, c.name or "") end
    row("Components", table.concat(names, ", "))
  end

  for _, sub in ipairs(f.subtasks or {}) do
    row("Subtask", (sub.key or "") .. "  "
      .. ((sub.fields and sub.fields.summary) or "")
      .. "  [" .. (name_of(sub.fields and sub.fields.status) or "?") .. "]")
  end

  for _, link in ipairs(f.issuelinks or {}) do
    local other = link.outwardIssue or link.inwardIssue
    if other then
      local rel = link.type
        and (link.outwardIssue and link.type.outward or link.type.inward)
        or "relates to"
      row("Link", rel .. " " .. (other.key or "") .. "  "
        .. ((other.fields and other.fields.summary) or ""))
    end
  end

  table.insert(lines, "")
  table.insert(lines, "## Description")
  table.insert(lines, "")
  local desc = M.adf(f.description)
  if #desc == 0 then
    table.insert(lines, "_No description._")
  else
    vim.list_extend(lines, desc)
  end

  local comments = (f.comment and f.comment.comments) or {}
  if #comments > 0 then
    table.insert(lines, "")
    table.insert(lines, ("## Comments (%d)"):format(f.comment.total or #comments))
    for _, c in ipairs(comments) do
      table.insert(lines, "")
      table.insert(lines, ("### %s · %s"):format(
        name_of(c.author) or "Unknown", short_date(c.created)))
      table.insert(lines, "")
      local body = M.adf(c.body)
      if #body == 0 then
        table.insert(lines, "_(empty)_")
      else
        vim.list_extend(lines, body)
      end
    end
  end

  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")
  local site = (issue.self or ""):match("^(https://[^/]+)") or ""
  table.insert(lines, site .. "/browse/" .. key)

  return lines
end

--- Fetch one issue and render it.
---@return string[]|nil lines, string|nil err
function M.detail(key)
  local out, err = jira({ "issue", "view", key, "--raw", "--comments", "50" })
  if not out then return nil, err end
  local lines = M.detail_from_json(out)
  if not lines then return nil, "Could not parse " .. key end
  return lines
end

--- Render an issue into a buffer: metadata, description, every comment.
function M.view(key)
  local lines, err = M.detail(key)
  if not lines then fail(err) return end
  show(key, table.concat(lines, "\n"))
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

-- This is the one place in the config that builds a picker by hand rather
-- than going through vim.ui.select. The point of the Jira layer is
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

-- Details already fetched this session, keyed by issue key. Moving back up the
-- list must not re-request, and a fetch that lands after you have moved on
-- must not overwrite the pane you are now looking at.
local detail_cache = {}

--- Fetch an issue's detail without blocking the picker.
---
--- The synchronous M.detail is fine for <leader>jv, where you asked for one
--- issue and can wait. It is wrong here: the previewer runs on every cursor
--- move, and :wait() would freeze the picker for the length of an HTTP call
--- each time you press j.
local function detail_async(key, callback)
  if detail_cache[key] then
    callback(detail_cache[key])
    return
  end

  local tok = token()
  if not tok then
    callback({ "Not authenticated — see :checkhealth nvim-config" })
    return
  end

  vim.system(
    { "jira", "issue", "view", key, "--raw", "--comments", "50" },
    { text = true, env = { JIRA_API_TOKEN = tok } },
    function(res)
      -- Everything below has to be inside vim.schedule. A vim.system callback
      -- runs in a fast event context, where vim.fn.* is forbidden, and the
      -- renderer reads jira-cli's config with vim.fn.readfile to resolve
      -- custom field ids. Parsing out here silently lost the Sprint and story
      -- point rows -- and cached the broken result for the whole session.
      vim.schedule(function()
        local lines
        if res.code ~= 0 then
          lines = { "Could not load " .. key, "", vim.trim(res.stderr or "") }
        else
          lines = M.detail_from_json(res.stdout or "") or { "Could not parse " .. key }
        end
        detail_cache[key] = lines
        callback(lines)
      end)
    end
  )
end

--- Show a list of issues in snacks.picker, with a live detail preview and the
--- actions on control keys. Double-click or <CR> opens the action menu.
function M.pick(title, issues)
  local items = {}
  for i, issue in ipairs(issues) do
    items[i] = {
      idx = i,
      issue = issue,
      -- Searchable on key, status, assignee and summary together, so "1841",
      -- "review" and "rounding" all find the same issue.
      text = table.concat({ issue.key, issue.status, issue.assignee, issue.summary }, " "),
    }
  end

  -- Close the picker first: every action either prompts or opens a window, and
  -- both fight with a picker that is still up.
  local function act(fn)
    return function(picker, item)
      item = item or picker:current()
      if not item then return end
      picker:close()
      vim.schedule(function() fn(item.issue.key) end)
    end
  end

  Snacks.picker.pick({
    title = title .. "   <CR> actions  ^t move  ^a assign  ^c comment  ^o browser",
    items = items,
    format = function(item) return { { entry(item.issue) } } end,
    preview = function(ctx)
      local issue = ctx.item.issue
      -- Something readable immediately, so the pane is never blank while the
      -- request is in flight.
      ctx.preview:reset()
      ctx.preview:set_lines({
        "# " .. issue.key .. " · " .. issue.summary,
        "",
        "`" .. issue.status .. "`  `" .. issue.assignee .. "`",
        "",
        "_Loading…_",
      })
      ctx.preview:highlight({ ft = "markdown" })
      detail_async(issue.key, function(lines)
        -- The cursor may have moved on while this was in flight; only paint if
        -- the picker is still showing the issue we asked about.
        local current = ctx.picker and not ctx.picker.closed and ctx.picker:current()
        if not current or current.issue.key ~= issue.key then return end
        ctx.preview:set_lines(lines)
        ctx.preview:highlight({ ft = "markdown" })
      end)
    end,
    confirm = act(menu),
    actions = {
      jira_move = act(M.move),
      jira_assign = act(M.assign),
      jira_comment = act(M.comment),
      jira_open = act(M.open),
      jira_view = act(M.view),
    },
    win = {
      input = {
        keys = {
          ["<C-t>"] = { "jira_move", mode = { "i", "n" } },
          ["<C-a>"] = { "jira_assign", mode = { "i", "n" } },
          ["<C-c>"] = { "jira_comment", mode = { "i", "n" } },
          ["<C-o>"] = { "jira_open", mode = { "i", "n" } },
          ["<C-v>"] = { "jira_view", mode = { "i", "n" } },
        },
      },
    },
  })
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

--- Free-text search across the project -- or a jump, when what you typed is an
--- issue key.
---
--- "AR-991" as a search term matches the issues that mention AR-991, which is
--- never what you wanted when you typed it: you wanted AR-991. So a key opens
--- the issue, and everything else searches. A bare "991" counts as a key too,
--- resolved against the configured project.
function M.search()
  vim.ui.input({ prompt = "Search issues (or an issue key): " }, function(text)
    if not text or vim.trim(text) == "" then return end

    local key = as_key(text)
    if key then M.view(key) return end

    -- Quotes would terminate the JQL string early and change the query.
    local term = vim.trim(text):gsub('"', "")

    -- `text ~` is the field Jira's own search box uses: summary, description,
    -- comments and environment at once, rather than the summary and description
    -- this checked before. An issue whose title says nothing but whose comments
    -- say everything is exactly the one you are trying to find again.
    --
    -- The trailing * makes it prefix-matching, so "round" finds "rounding".
    -- That is half of what the board's filter box does and all Jira will give:
    -- `~` is a full-text index, so it matches whole words, and a LEADING
    -- wildcard is rejected outright -- "ing" will never find "rounding".
    -- Skipped when you have written a wildcard yourself.
    if not term:find("*", 1, true) then term = term .. "*" end

    local jql = string.format('text ~ "%s" ORDER BY updated DESC', term)
    show_list("Search: " .. vim.trim(text), function() return M.jql_issues(jql) end)
  end)
end

--- The raw jira-cli explorer, for anything this layer does not wrap.
function M.tui()
  in_terminal("jira sprint list --current")
end

return M
