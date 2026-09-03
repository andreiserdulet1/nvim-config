-- Angular CLI, driven from the editor.
--
-- Two things make this more than a shell alias:
--
--  * It knows where you are. `ng generate` is given a path relative to the
--    project you're editing, so generating from inside src/app/features/orders
--    puts the new component there instead of at the app root.
--
--  * Nothing is written until you've seen what will be written. Every generate
--    runs with --dry-run first and shows the file list; you confirm, then it
--    runs for real. That is the part WebStorm's dialog gets right.
--
-- The schematic list is read from `ng generate --help` in the current
-- workspace, so it reflects what that repo actually has installed (your
-- angular-eslint schematics show up in advertiser-payments-ui, for instance)
-- rather than a list hardcoded here.

local M = {}

local schematic_cache = {}

---------------------------------------------------------------------------
-- Workspace
---------------------------------------------------------------------------

local function workspace()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then dir = vim.uv.cwd() end

  local file = vim.fs.find("angular.json", { upward = true, path = dir, type = "file" })[1]
  if not file then return nil, "Not an Angular workspace (no angular.json above this file)" end

  local ok, content = pcall(vim.fn.readfile, file)
  if not ok then return nil, "Could not read " .. file end

  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(content, "\n"),
    { luanil = { object = true } })
  if not decoded_ok or type(decoded) ~= "table" or type(decoded.projects) ~= "table" then
    return nil, "Could not parse angular.json"
  end

  local root = vim.fn.fnamemodify(file, ":h")
  local projects = {}
  for name, p in pairs(decoded.projects) do
    table.insert(projects, {
      name = name,
      root = p.root or "",
      source_root = p.sourceRoot or "src",
      type = p.projectType or "application",
    })
  end
  -- Longest root first, so prefix matching picks the most specific project.
  table.sort(projects, function(a, b) return #a.root > #b.root end)

  local ng = root .. "/node_modules/.bin/ng"
  if vim.fn.executable(ng) == 0 then
    return nil, "No Angular CLI in this repo — run `yarn install` first"
  end

  return { root = root, projects = projects, ng = ng }
end

-- Which project does the current file belong to? None of your repos set
-- defaultProject (Angular dropped it), and awin-angular-libraries has fifteen
-- projects, so this has to be worked out rather than assumed.
local function project_for(ws, path)
  if #ws.projects == 1 then return ws.projects[1] end

  local rel = path:sub(#ws.root + 2)
  for _, p in ipairs(ws.projects) do
    if p.root ~= "" and vim.startswith(rel, p.root .. "/") then return p end
  end
  return nil   -- caller prompts
end

-- The directory of the current buffer, relative to the project's app folder.
-- Used to prefill the name so `ng g c` lands beside the file you're in.
local function path_prefix(ws, project, path)
  local dir = vim.fn.fnamemodify(path, ":h")
  local bases = { ws.root .. "/" .. project.source_root .. "/app", ws.root .. "/" .. project.source_root }
  for _, base in ipairs(bases) do
    if vim.startswith(dir, base .. "/") then
      return dir:sub(#base + 2) .. "/"
    elseif dir == base then
      return ""
    end
  end
  return ""
end

---------------------------------------------------------------------------
-- Schematics, read from the workspace itself
---------------------------------------------------------------------------

function M.schematics(ws)
  if schematic_cache[ws.root] then return schematic_cache[ws.root] end

  local res = vim.system({ ws.ng, "generate", "--help" }, { cwd = ws.root, text = true }):wait()
  local list = {}
  for line in ((res.stdout or "") .. (res.stderr or "")):gmatch("[^\r\n]+") do
    -- "  ng generate component [name]   Creates a new Angular component. ..."
    local name, rest = line:match("^%s+ng generate ([%w%-:]+)%s+(.*)$")
    if name and name ~= "<schematic>" then
      local desc = rest:gsub("^%[[^%]]*%]%s*", ""):gsub("^%s+", "")
      desc = desc:gsub("%s+%[aliases:.*$", ""):gsub("%s+%[default%]", "")
      -- first sentence is plenty for a picker row
      desc = desc:match("^([^%.]+)%.") or desc
      table.insert(list, { name = name, desc = desc })
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  schematic_cache[ws.root] = list
  return list
end

---------------------------------------------------------------------------
-- The confirm-before-writing window
---------------------------------------------------------------------------

local function confirm_window(title, lines, on_accept)
  local width = 0
  for _, l in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(l)) end
  width = math.min(math.max(width + 4, 46), vim.o.columns - 6)
  local height = math.min(#lines + 2, vim.o.lines - 6)

  local buf = vim.api.nvim_create_buf(false, true)
  local body = { "" }
  for _, l in ipairs(lines) do table.insert(body, "  " .. l) end
  table.insert(body, "")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, body)

  local ns = vim.api.nvim_create_namespace("ng-confirm")
  for i, l in ipairs(body) do
    local group = l:match("^%s+CREATE") and "DiffAdd"
      or l:match("^%s+UPDATE") and "DiffChange"
      or l:match("^%s+DELETE") and "DiffDelete"
      or nil
    if group then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0,
        { end_row = i - 1, end_col = #l, hl_group = group })
    end
  end

  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. "   [y] create   [q] cancel ",
    title_pos = "center",
  })
  vim.wo[win].cursorline = false

  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  for _, key in ipairs({ "y", "<CR>" }) do
    vim.keymap.set("n", key, function() close(); on_accept() end,
      { buffer = buf, nowait = true, silent = true })
  end
  for _, key in ipairs({ "q", "<Esc>", "n" }) do
    vim.keymap.set("n", key, function() close(); vim.notify("Cancelled") end,
      { buffer = buf, nowait = true, silent = true })
  end
end

---------------------------------------------------------------------------
-- Generate
---------------------------------------------------------------------------

local function run_generate(ws, project, schematic, name, dry)
  local args = { ws.ng, "generate", schematic, name, "--project=" .. project.name, "--interactive=false" }
  if dry then table.insert(args, "--dry-run") end
  return vim.system(args, { cwd = ws.root, text = true }):wait()
end

local function parse_files(out)
  local lines, created = {}, {}
  for line in (out or ""):gmatch("[^\r\n]+") do
    local verb, path = line:match("^(%u+)%s+(%S+)")
    if verb == "CREATE" or verb == "UPDATE" or verb == "DELETE" then
      table.insert(lines, line)
      if verb == "CREATE" and path:match("%.ts$") and not path:match("%.spec%.ts$") then
        table.insert(created, path)
      end
    end
  end
  return lines, created
end

--- Generate one schematic. Prompts for the name, previews, then writes.
function M.generate(schematic)
  local ws, err = workspace()
  if not ws then vim.notify(err, vim.log.levels.WARN) return end

  local path = vim.api.nvim_buf_get_name(0)

  local function go(project)
    local prefix = path ~= "" and path_prefix(ws, project, path) or ""
    vim.ui.input({ prompt = "ng generate " .. schematic .. " ", default = prefix },
      function(name)
        if not name or name == "" or name:match("/$") then
          vim.notify("Cancelled")
          return
        end

        local res = run_generate(ws, project, schematic, name, true)
        local out = (res.stdout or "") .. (res.stderr or "")
        if res.code ~= 0 then
          vim.notify("ng generate failed:\n" .. out, vim.log.levels.ERROR)
          return
        end

        local files = parse_files(out)
        if #files == 0 then
          vim.notify("Nothing to generate:\n" .. out, vim.log.levels.WARN)
          return
        end

        confirm_window(schematic .. "  ->  " .. project.name, files, function()
          local real = run_generate(ws, project, schematic, name, false)
          local rout = (real.stdout or "") .. (real.stderr or "")
          if real.code ~= 0 then
            vim.notify("ng generate failed:\n" .. rout, vim.log.levels.ERROR)
            return
          end
          local _, created = parse_files(rout)
          vim.notify("Generated " .. schematic .. " " .. name)
          if created[1] then
            vim.cmd.edit(vim.fn.fnameescape(ws.root .. "/" .. created[1]))
          end
        end)
      end)
  end

  local project = project_for(ws, path)
  if project then
    go(project)
  else
    -- Multi-project workspace and the current file isn't inside one of them.
    local names = vim.tbl_map(function(p) return p.name end, ws.projects)
    vim.ui.select(names, { prompt = "Which project?" }, function(choice)
      if not choice then return end
      for _, p in ipairs(ws.projects) do
        if p.name == choice then go(p) return end
      end
    end)
  end
end

--- Pick any schematic this workspace offers, then generate it.
function M.generate_pick()
  local ws, err = workspace()
  if not ws then vim.notify(err, vim.log.levels.WARN) return end

  local list = M.schematics(ws)
  if #list == 0 then
    vim.notify("Could not read the schematic list from ng", vim.log.levels.WARN)
    return
  end

  vim.ui.select(list, {
    prompt = "ng generate",
    format_item = function(s) return string.format("%-24s %s", s.name, s.desc) end,
  }, function(choice)
    if choice then M.generate(choice.name) end
  end)
end

---------------------------------------------------------------------------
-- Everything else ng can do
---------------------------------------------------------------------------

-- For serve/build/test/lint the package.json script is preferred when one
-- exists, because some of your repos wrap ng with an env prelude — running
-- `ng test` directly in advertiser-payments-ui skips load-env.mjs and fails.
local COMMANDS = {
  { label = "serve",        args = { "serve" },                 script = "start" },
  { label = "build",        args = { "build" },                 script = "build" },
  { label = "test",         args = { "test" },                  script = "test" },
  { label = "lint",         args = { "lint" },                  script = "lint" },
  { label = "extract-i18n", args = { "extract-i18n" },          script = "i18n" },
  { label = "update",       args = { "update" },                desc = "list available Angular updates" },
  { label = "add",          args = { "add" },                   prompt = "Package to add: " },
  { label = "version",      args = { "version" } },
  { label = "cache info",   args = { "cache", "info" } },
  { label = "cache clean",  args = { "cache", "clean" } },
  { label = "config",       args = { "config" },                desc = "print the workspace config" },
  { label = "analytics info", args = { "analytics", "info" } },
}

function M.palette()
  local ws, err = workspace()
  if not ws then vim.notify(err, vim.log.levels.WARN) return end

  vim.ui.select(COMMANDS, {
    prompt = "ng — " .. vim.fn.fnamemodify(ws.root, ":t"),
    format_item = function(c)
      local via = c.script and (" (via yarn " .. c.script .. " if defined)") or ""
      return string.format("%-16s %s", "ng " .. c.label, c.desc or via)
    end,
  }, function(choice)
    if not choice then return end

    local function launch(extra)
      local args = vim.deepcopy(choice.args)
      if extra and extra ~= "" then table.insert(args, extra) end

      -- Delegate to the package.json script when the repo defines one, so any
      -- env prelude still runs.
      if choice.script then
        local scripts = require("config.scripts")
        local pkg = ws.root .. "/package.json"
        local ok, content = pcall(vim.fn.readfile, pkg)
        if ok then
          local dok, decoded = pcall(vim.json.decode, table.concat(content, "\n"),
            { luanil = { object = true } })
          if dok and type(decoded) == "table" and type(decoded.scripts) == "table"
            and decoded.scripts[choice.script] then
            scripts.run(choice.script)
            return
          end
        end
      end

      require("toggleterm.terminal").Terminal
        :new({
          cmd = "node_modules/.bin/ng " .. table.concat(args, " "),
          dir = ws.root,
          direction = "float",
          close_on_exit = false,
          hidden = true,
        })
        :toggle()
    end

    if choice.prompt then
      vim.ui.input({ prompt = choice.prompt }, function(v)
        if v and v ~= "" then launch(v) end
      end)
    else
      launch()
    end
  end)
end

return M
