-- Tests in the gutter, the way WebStorm does it.
--
-- Every describe / it in a .spec.ts gets a ▶ in the sign column. Click it (or
-- <leader>nT on the line) to run just that test; after a run the marks turn
-- into ✓ and ✗. Right-click a ✗ to hand the failure to Claude.
--
-- Karma has no "run the test called X" switch that `ng test` passes through,
-- so a single test is run the way you would by hand: a copy of the spec sits
-- next to it for the length of the run, with that one `it` turned into `fit`
-- (or `describe` into `fdescribe`), and only that copy is --include'd. The
-- copy is deleted when the run ends; your file is never touched.
--
-- Coverage: <leader>nC runs this spec with --code-coverage and colours the
-- line numbers of the files it covers (green run, red never run), read from
-- the HTML report Angular's default Karma setup writes. <leader>uC toggles it.

local M = {}

local ns = vim.api.nvim_create_namespace("config_tests")
local cov_ns = vim.api.nvim_create_namespace("config_coverage")

local FNS = { describe = "describe", fdescribe = "describe", xdescribe = "describe",
  it = "it", fit = "it", xit = "it" }

-- Results of the last run, per spec file: [full name] = { ok = bool, output = string }
M.results = {}
-- The last run, for <leader>nf / sending to Claude.
M.last = nil

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "tests" })
end

local function is_spec(buf)
  return vim.api.nvim_buf_get_name(buf):match("%.spec%.ts$") ~= nil
end

---------------------------------------------------------------------------
-- Finding the tests
---------------------------------------------------------------------------

local QUERY = [[
(call_expression
  function: (identifier) @fn
  arguments: (arguments . [(string) (template_string)] @name)) @call
]]

local function unquote(text)
  return (text:gsub("^['\"`]", ""):gsub("['\"`]$", ""))
end

--- Every describe / it in `buf`, each with its full Jasmine name.
---@return { kind: string, fn: string, name: string, full: string, line: integer, last: integer }[]
function M.discover(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "typescript")
  if not ok or not parser then return {} end
  local tree = parser:parse()[1]
  local query = vim.treesitter.query.parse("typescript", QUERY)

  local found = {}
  for _, match in query:iter_matches(tree:root(), buf, 0, -1) do
    local fn_node, name_node, call_node
    for id, nodes in pairs(match) do
      local node = type(nodes) == "table" and nodes[#nodes] or nodes
      local cap = query.captures[id]
      if cap == "fn" then fn_node = node elseif cap == "name" then name_node = node else call_node = node end
    end
    local fn = fn_node and vim.treesitter.get_node_text(fn_node, buf)
    if fn and FNS[fn] and name_node and call_node then
      local sr, _, er = call_node:range()
      table.insert(found, {
        kind = FNS[fn], fn = fn,
        name = unquote(vim.treesitter.get_node_text(name_node, buf)),
        line = sr + 1, last = er + 1,
      })
    end
  end
  table.sort(found, function(a, b) return a.line < b.line end)

  -- Jasmine's full name: every enclosing describe, then the name, by spaces.
  for _, item in ipairs(found) do
    local chain = {}
    for _, d in ipairs(found) do
      if d.kind == "describe" and d ~= item and d.line <= item.line and d.last >= item.last then
        table.insert(chain, d.name)
      end
    end
    table.insert(chain, item.name)
    item.full = table.concat(chain, " ")
  end
  return found
end

--- The test on `line`, or the innermost one around it.
function M.at(buf, line)
  local best
  for _, item in ipairs(M.discover(buf)) do
    if item.line == line then return item end
    if item.line <= line and item.last >= line and (not best or item.line > best.line) then best = item end
  end
  return best
end

---------------------------------------------------------------------------
-- Marks
---------------------------------------------------------------------------

local function status_of(spec, item, items)
  local res = M.results[spec]
  if not res then return nil end
  if item.kind == "it" then
    return res[item.full] and (res[item.full].ok and "pass" or "fail") or nil
  end
  -- A describe: failed if anything inside failed, passed if everything ran and passed.
  local any, all = false, true
  for _, child in ipairs(items) do
    if child.kind == "it" and child.line > item.line and child.last <= item.last then
      local r = res[child.full]
      if r and not r.ok then return "fail" end
      if r then any = true else all = false end
    end
  end
  return (any and all) and "pass" or nil
end

local ICON = { pass = "✓", fail = "✗" }
local HL = { pass = "DiagnosticOk", fail = "DiagnosticError" }

function M.render(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not is_spec(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local spec = vim.api.nvim_buf_get_name(buf)
  local items = M.discover(buf)
  for _, item in ipairs(items) do
    local st = status_of(spec, item, items)
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, item.line - 1, 0, {
      sign_text = st and ICON[st] or "▶",
      sign_hl_group = st and HL[st] or "Function",
      priority = 20,
    })
  end
end

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------

local function strip(s)
  return (s:gsub("\27%[[%d;?]*%a", ""))
end

--- Karma's progress reporter: "<browser> (<os>) <full name> FAILED", then the
--- error indented beneath it.
local function parse(lines)
  local failed, current = {}, nil
  local executed = false
  for _, raw in ipairs(lines) do
    for _, part in ipairs(vim.split(strip(raw), "\r", { plain = true })) do
      local name = part:match("%) (.-) FAILED%s*$")
      if name and not part:match("Executed") then
        current = { name = name, output = { part } }
        table.insert(failed, current)
      elseif part:match("Executed %d+ of %d+") then
        executed = true
        current = nil
      elseif current and part:match("^%s") then
        table.insert(current.output, part)
      end
    end
  end
  return failed, executed
end

local term

--- Run the test on `line` of `buf` (or the whole spec when line is nil).
---@param opts { coverage: boolean }|nil
function M.run(buf, line, opts)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  opts = opts or {}
  local spec = vim.api.nvim_buf_get_name(buf)
  if not is_spec(buf) then
    -- From a component: run its spec.
    local sibling = require("config.component").sibling_path("spec", spec)
    if not sibling then notify("No spec for this file", vim.log.levels.WARN) return end
    spec, line = sibling, nil
    buf = vim.fn.bufadd(spec)
    vim.fn.bufload(buf)
  end

  local scripts = require("config.scripts")
  local proj, err = scripts.project(vim.fs.dirname(spec))
  if not proj then notify(err, vim.log.levels.WARN) return end
  local script, needs_no_watch = scripts.test_script(proj.scripts)
  if not script then notify("No test script in " .. proj.name, vim.log.levels.WARN) return end

  local items = M.discover(buf)
  local target = line and M.at(buf, line) or nil
  local include, focus_copy = spec, nil
  if target then
    -- Focus a copy: `it(` → `fit(`, `xit(` → `fit(`, same for describe.
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local l = lines[target.line]
    local col = l:find(target.fn .. "%s*%(")
    if col then
      local focused = "f" .. target.kind
      lines[target.line] = l:sub(1, col - 1) .. focused .. l:sub(col + #target.fn)
      focus_copy = spec:gsub("%.spec%.ts$", ".nvim-focus.spec.ts")
      vim.fn.writefile(lines, focus_copy)
      include = focus_copy
    end
  end

  -- What this run covers, so the ones that did not fail can be marked ✓.
  local scope = {}
  for _, item in ipairs(items) do
    if item.kind == "it" and (not target or (item.line >= target.line and item.last <= target.last)) then
      table.insert(scope, item)
    end
  end

  local cmd = "yarn " .. script .. " --include=" .. include:sub(#proj.root + 2)
  if needs_no_watch then cmd = cmd .. " --watch=false" end
  if opts.coverage then cmd = cmd .. " --code-coverage" end
  if vim.fn.executable("direnv") == 1 and vim.uv.fs_stat(proj.root .. "/.envrc") then
    cmd = "direnv exec . " .. cmd
  end

  if term then pcall(function() term:shutdown() end) end
  local output = {}
  local label = target and target.name or vim.fs.basename(spec)
  notify("Running " .. label .. " …")
  term = require("toggleterm.terminal").Terminal:new({
    cmd = cmd,
    dir = proj.root,
    hidden = true,
    direction = "float",
    close_on_exit = false,
    display_name = "test · " .. label,
    on_stdout = function(_, _, data) vim.list_extend(output, data) end,
    on_exit = function(_, _, code)
      vim.schedule(function()
        if focus_copy then os.remove(focus_copy) end
        local failed, executed = parse(output)
        local res = M.results[spec] or {}
        for _, item in ipairs(scope) do
          if executed then res[item.full] = { ok = true } end
        end
        for _, f in ipairs(failed) do
          for _, item in ipairs(scope) do
            if f.name == item.full or vim.endswith(f.name, item.full) then
              res[item.full] = { ok = false, output = table.concat(f.output, "\n") }
            end
          end
        end
        M.results[spec] = res
        M.last = { spec = spec, failed = failed, executed = executed, code = code, output = output, label = label }
        if vim.api.nvim_buf_is_loaded(buf) then M.render(buf) end

        if code == 0 then
          notify(("✓ %s — %d passed"):format(label, #scope))
        elseif not executed then
          notify("✗ " .. label .. " did not run (compile error?) — <leader>nf to see it, <leader>ae for Claude",
            vim.log.levels.ERROR)
        else
          notify(("✗ %s — %d failed. <leader>nf output · right-click ✗ → Claude"):format(label, #failed),
            vim.log.levels.ERROR)
        end
        if opts.coverage then M.coverage_show(true) end
      end)
    end,
  })
  term:spawn()
end

--- Run the test under the cursor.
function M.run_nearest()
  M.run(0, vim.fn.line("."))
end

--- Run the whole spec (from the spec or its component).
function M.run_file()
  M.run(0, nil)
end

--- Run the last test again.
function M.rerun()
  if not M.last then notify("Nothing has run yet") return end
  M.run(vim.fn.bufadd(M.last.spec), nil)
end

--- Show the last run's output.
function M.output()
  if not term then notify("Nothing has run yet") return end
  term:toggle()
end

--- Hand the failure on this line -- or the whole last run -- to Claude.
function M.send_failure()
  local buf = vim.api.nvim_get_current_buf()
  local spec = vim.api.nvim_buf_get_name(buf)
  local item = is_spec(buf) and M.at(buf, vim.fn.line(".")) or nil
  local r = item and M.results[spec] and M.results[spec][item.full]
  local claude = require("config.claude")
  local function relpath(path)
    local root = vim.fs.root(path, ".git")
    return root and path:sub(#root + 2) or vim.fn.fnamemodify(path, ":.")
  end
  local rel = relpath(spec)
  if r and not r.ok and r.output then
    claude.ask_with(("This Karma test fails: \"%s\" in @%s#L%d.\n```\n%s\n```\nFind out whether the test or the code is wrong, and fix it.")
      :format(item.full, rel, item.line, r.output))
    return
  end
  if not M.last or M.last.code == 0 then notify("No failing test to send") return end
  local tail = vim.list_slice(M.last.output, math.max(1, #M.last.output - 120))
  claude.ask_with(("Running the Karma tests for @%s failed:\n```\n%s\n```\nFind the cause and fix it.")
    :format(relpath(M.last.spec), strip(table.concat(tail, "\n"))))
end

---------------------------------------------------------------------------
-- Coverage
---------------------------------------------------------------------------

M.coverage_on = false

-- coverage/<project>/app/x.ts.html for src/app/x.ts -- the report drops the
-- source root, so match on the path's tail.
local function coverage_html(file)
  local root = vim.fs.root(file, "package.json")
  if not root or vim.fn.isdirectory(root .. "/coverage") == 0 then return nil end
  local rel = file:sub(#root + 2):gsub("^src/", "")
  local hits = vim.fs.find(vim.fs.basename(file) .. ".html", { path = root .. "/coverage", limit = 20 })
  for _, h in ipairs(hits) do
    if vim.endswith(h, rel .. ".html") then return h end
  end
  return hits[1]
end

local function apply_coverage(buf)
  vim.api.nvim_buf_clear_namespace(buf, cov_ns, 0, -1)
  if not M.coverage_on then return end
  local file = vim.api.nvim_buf_get_name(buf)
  if not file:match("%.ts$") or file:match("%.spec%.ts$") then return end
  local html = coverage_html(file)
  if not html then return end
  local ok, text = pcall(function() return table.concat(vim.fn.readfile(html), "\n") end)
  if not ok then return end
  local n = 0
  for state in text:gmatch("cline%-any cline%-(%a+)") do
    n = n + 1
    local hl = state == "yes" and "DiagnosticOk" or (state == "no" and "DiagnosticError" or nil)
    if hl then
      pcall(vim.api.nvim_buf_set_extmark, buf, cov_ns, n - 1, 0, { number_hl_group = hl, priority = 5 })
    end
  end
  local fstat, hstat = vim.uv.fs_stat(file), vim.uv.fs_stat(html)
  if fstat and hstat and fstat.mtime.sec > hstat.mtime.sec then
    notify(vim.fs.basename(file) .. " changed since its coverage was measured", vim.log.levels.WARN)
  end
end

--- Turn the coverage colours on (true), off (false), or flip them (nil).
function M.coverage_show(on)
  if on == nil then on = not M.coverage_on end
  M.coverage_on = on
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then apply_coverage(buf) end
  end
  notify("Coverage " .. (on and "on — green ran, red never ran" or "off"))
end

--- Run this spec with coverage, then show it.
function M.run_coverage()
  M.run(0, nil, { coverage = true })
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

function M.setup()
  local group = vim.api.nvim_create_augroup("config_tests", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "BufEnter" }, {
    group = group,
    pattern = "*.spec.ts",
    callback = function(ev) M.render(ev.buf) end,
  })
  -- Room for the ▶ beside the git and diagnostic signs -- and back to one
  -- column when the window moves on to something else.
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      if is_spec(ev.buf) then
        vim.wo.signcolumn = "yes:2"
      elseif vim.wo.signcolumn == "yes:2" then
        vim.wo.signcolumn = "yes"
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    pattern = "*.ts",
    callback = function(ev) if M.coverage_on then apply_coverage(ev.buf) end end,
  })
end

return M
