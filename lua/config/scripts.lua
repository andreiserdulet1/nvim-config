-- Running this project's scripts: the picker, plus dedicated test keys.
--
-- Everything goes through M.run, which always invokes the *named script* via
-- yarn rather than a reconstructed command. That is what makes
-- advertiser-payments-ui work: its test script is
--   node scripts/load-env.mjs development && ng test
-- and yarn 1.x appends our extra arguments after it, so the env prelude still
-- happens. Rebuilding the command ourselves would silently skip it.

local M = {}

-- Scripts you reach for most, pinned to the top of the picker; the rest follow
-- alphabetically.
local PREFERRED = { "start", "test", "test-headless", "lint", "build", "watch" }

local function nearest_package_json()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    dir = vim.uv.cwd()
  end
  return vim.fs.find("package.json", { upward = true, path = dir, type = "file" })[1]
end

-- Returns the decoded package.json and its directory, or nil plus a reason.
local function project()
  local pkg = nearest_package_json()
  if not pkg then return nil, "No package.json above this file" end

  local read_ok, content = pcall(vim.fn.readfile, pkg)
  if not read_ok then return nil, "Could not read " .. pkg end

  local ok, decoded = pcall(vim.json.decode, table.concat(content, "\n"),
    { luanil = { object = true } })
  if not ok or type(decoded) ~= "table" then
    return nil, "Could not parse " .. vim.fn.fnamemodify(pkg, ":~:.")
  end

  return {
    root = vim.fn.fnamemodify(pkg, ":h"),
    scripts = type(decoded.scripts) == "table" and decoded.scripts or {},
    name = decoded.name or vim.fn.fnamemodify(vim.fn.fnamemodify(pkg, ":h"), ":t"),
  }
end

--- Run a package.json script in a floating terminal at the project root.
---@param script string the script name, as written in package.json
---@param args string[]|nil extra arguments appended after the script
function M.run(script, args)
  local proj, err = project()
  if not proj then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  if not proj.scripts[script] then
    vim.notify("No '" .. script .. "' script in " .. proj.name, vim.log.levels.WARN)
    return
  end

  local cmd = "yarn " .. script
  if args and #args > 0 then
    cmd = cmd .. " " .. table.concat(args, " ")
  end

  require("toggleterm.terminal").Terminal
    :new({
      cmd = cmd,
      dir = proj.root,
      direction = "float",
      close_on_exit = false,   -- keep failures on screen
      hidden = true,
    })
    :toggle()
end

local function ordered(scripts)
  local names, seen = {}, {}
  for _, want in ipairs(PREFERRED) do
    if scripts[want] then
      table.insert(names, want)
      seen[want] = true
    end
  end
  local rest = {}
  for name in pairs(scripts) do
    if not seen[name] then table.insert(rest, name) end
  end
  table.sort(rest)
  vim.list_extend(names, rest)
  return names
end

--- Pick any script from this project's package.json and run it.
function M.pick()
  local proj, err = project()
  if not proj then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local names = ordered(proj.scripts)
  if #names == 0 then
    vim.notify("No scripts in " .. proj.name, vim.log.levels.WARN)
    return
  end

  -- vim.ui.select is routed through telescope-ui-select, so this matches every
  -- other picker in the config.
  vim.ui.select(names, {
    prompt = "yarn — " .. vim.fn.fnamemodify(proj.root, ":t"),
    format_item = function(name)
      return string.format("%-22s %s", name, proj.scripts[name])
    end,
  }, function(choice)
    if choice then M.run(choice) end
  end)
end

-- Every repo here runs Karma. `test-headless` avoids popping a Chrome window,
-- so prefer it when the repo defines one; note whether we had to fall back,
-- because the plain `test` script still needs --watch=false for a one-shot run
-- while the headless ones already pass --no-watch.
local function test_script(scripts)
  if scripts["test-headless"] then return "test-headless", false end
  if scripts["test"] then return "test", true end
  return nil, false
end

--- Run only the current component's spec.
function M.test_file()
  local proj, err = project()
  if not proj then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local script, needs_no_watch = test_script(proj.scripts)
  if not script then
    vim.notify("No test script in " .. proj.name, vim.log.levels.WARN)
    return
  end

  -- From a template or stylesheet, test the component it belongs to.
  local spec = require("config.component").sibling_path("spec")
  if not spec then
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
    vim.notify("No spec file for " .. name, vim.log.levels.WARN)
    return
  end

  -- --include wants a path relative to the project root.
  local rel = spec:sub(#proj.root + 2)
  local args = { "--include=" .. rel }
  if needs_no_watch then table.insert(args, "--watch=false") end

  vim.notify("Testing " .. vim.fn.fnamemodify(spec, ":t"))
  M.run(script, args)
end

--- Run the whole suite. Pass true to leave Karma watching.
function M.test_all(watch)
  local proj, err = project()
  if not proj then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  if watch then
    if not proj.scripts["test"] then
      vim.notify("No test script in " .. proj.name, vim.log.levels.WARN)
      return
    end
    M.run("test")
    return
  end

  local script, needs_no_watch = test_script(proj.scripts)
  if not script then
    vim.notify("No test script in " .. proj.name, vim.log.levels.WARN)
    return
  end
  M.run(script, needs_no_watch and { "--watch=false" } or nil)
end

return M
