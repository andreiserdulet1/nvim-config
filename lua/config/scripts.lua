-- package.json script runner.
--
-- Each of your repos starts and tests differently: commissions-ui runs
-- `ng serve commissions -o`, prepayment-ui runs `npx ng serve`, and
-- advertiser-payments-ui must run `node scripts/load-env.mjs development`
-- before `ng test` or the tests fail.
--
-- So this always runs the *named script* through yarn, never a reconstructed
-- command. Whatever the repo's package.json says is what happens.

local M = {}

-- Scripts you reach for most, pinned to the top of the list; everything else
-- follows alphabetically.
local PREFERRED = { "start", "test", "test-headless", "lint", "build", "watch" }

local function nearest_package_json()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    dir = vim.uv.cwd()
  end
  return vim.fs.find("package.json", { upward = true, path = dir, type = "file" })[1]
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

function M.pick()
  local pkg = nearest_package_json()
  if not pkg then
    vim.notify("No package.json above this file", vim.log.levels.WARN)
    return
  end

  local ok, content = pcall(vim.fn.readfile, pkg)
  if not ok then
    vim.notify("Could not read " .. pkg, vim.log.levels.ERROR)
    return
  end

  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(content, "\n"),
    { luanil = { object = true } })
  if not decoded_ok or type(decoded) ~= "table" or type(decoded.scripts) ~= "table" then
    vim.notify("No scripts in " .. vim.fn.fnamemodify(pkg, ":~:."), vim.log.levels.WARN)
    return
  end

  local root = vim.fn.fnamemodify(pkg, ":h")
  local names = ordered(decoded.scripts)
  if #names == 0 then
    vim.notify("No scripts in " .. vim.fn.fnamemodify(pkg, ":~:."), vim.log.levels.WARN)
    return
  end

  -- vim.ui.select is routed through telescope-ui-select, so this looks and
  -- behaves like every other picker in the config.
  vim.ui.select(names, {
    prompt = "yarn — " .. vim.fn.fnamemodify(root, ":t"),
    format_item = function(name)
      return string.format("%-22s %s", name, decoded.scripts[name])
    end,
  }, function(choice)
    if not choice then return end
    require("toggleterm.terminal").Terminal
      :new({
        cmd = "yarn " .. choice,
        dir = root,
        direction = "float",
        close_on_exit = false,   -- keep failures on screen
        hidden = true,
      })
      :toggle()
  end)
end

return M
