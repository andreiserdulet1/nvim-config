-- Angular component file switcher.
--
-- A component is spread over up to four files that share a stem:
--
--   money-cell.component.ts      <- the class
--   money-cell.component.html    <- the template   (often absent: inline templates)
--   money-cell.component.scss    <- the styles
--   money-cell.component.spec.ts <- the tests
--
-- This jumps between them. It also works for services and pipes, where the
-- useful pair is just the file and its .spec.ts.

local M = {}

-- .scss everywhere in your repos, but don't break in one that differs.
local STYLE_EXTS = { "scss", "css", "sass", "less" }

local KINDS = { "ts", "html", "style", "spec" }

local LABEL = {
  ts = "TypeScript",
  html = "template",
  style = "styles",
  spec = "spec",
}

-- Work out which of the four the current file is, and the stem the others share.
-- Order matters: ".spec.ts" must be tested before ".ts", or a spec file would be
-- classified as the class and resolve its stem one extension short.
local function classify(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  local name = vim.fn.fnamemodify(path, ":t")

  if name:match("%.spec%.ts$") then
    return dir, (name:gsub("%.spec%.ts$", "")), "spec"
  end
  if name:match("%.ts$") then
    return dir, (name:gsub("%.ts$", "")), "ts"
  end
  if name:match("%.html$") then
    return dir, (name:gsub("%.html$", "")), "html"
  end
  for _, ext in ipairs(STYLE_EXTS) do
    if name:match("%." .. ext .. "$") then
      return dir, (name:gsub("%." .. ext .. "$", "")), "style"
    end
  end
  return nil
end

-- Path of a given sibling, or nil when that file doesn't exist.
local function resolve(dir, stem, kind)
  local function readable(p)
    return vim.fn.filereadable(p) == 1 and p or nil
  end

  if kind == "ts" then
    return readable(dir .. "/" .. stem .. ".ts")
  elseif kind == "html" then
    return readable(dir .. "/" .. stem .. ".html")
  elseif kind == "spec" then
    return readable(dir .. "/" .. stem .. ".spec.ts")
  elseif kind == "style" then
    for _, ext in ipairs(STYLE_EXTS) do
      local hit = readable(dir .. "/" .. stem .. "." .. ext)
      if hit then return hit end
    end
  end
  return nil
end

-- Most of prepayment-ui writes its templates inline, so a missing .html is
-- usually not a mistake. Say so rather than reporting a bare "not found".
local function uses_inline_template(dir, stem)
  local ts = resolve(dir, stem, "ts")
  if not ts then return false end
  local ok, lines = pcall(vim.fn.readfile, ts)
  if not ok then return false end
  for _, line in ipairs(lines) do
    if line:match("template%s*:") then return true end
  end
  return false
end

local function any_sibling_exists(dir, stem, except)
  for _, kind in ipairs(KINDS) do
    if kind ~= except and resolve(dir, stem, kind) then return true end
  end
  return false
end

--- Path of a sibling file, without opening it. Returns nil when it doesn't
--- exist, or when this isn't a component-shaped file at all. Used by the test
--- runner in config/scripts.lua so that pressing the test key inside a template
--- tests the component the template belongs to.
---@param kind string one of "ts", "html", "style", "spec"
---@param path string|nil defaults to the current buffer
function M.sibling_path(kind, path)
  path = path or vim.api.nvim_buf_get_name(0)
  if path == "" then return nil end
  local dir, stem, current = classify(path)
  if not dir then return nil end
  if kind == current then return path end
  return resolve(dir, stem, kind)
end

--- Open a specific sibling of the current component.
function M.open(kind)
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("No file in this buffer", vim.log.levels.WARN)
    return
  end

  local dir, stem, current = classify(path)
  if not dir then
    vim.notify("Not an Angular component file", vim.log.levels.WARN)
    return
  end

  if kind == current then
    vim.notify("Already in the " .. LABEL[kind] .. " file")
    return
  end

  local target = resolve(dir, stem, kind)
  if target then
    vim.cmd.edit(vim.fn.fnameescape(target))
    return
  end

  if kind == "html" and uses_inline_template(dir, stem) then
    vim.notify("No template file - this component uses an inline template")
  elseif not any_sibling_exists(dir, stem, current) then
    vim.notify("No component files alongside " .. vim.fn.fnamemodify(path, ":t"))
  else
    vim.notify("No " .. LABEL[kind] .. " file for " .. stem)
  end
end

--- Cycle to the next sibling that actually exists.
function M.cycle()
  local path = vim.api.nvim_buf_get_name(0)
  local dir, stem, current = classify(path)
  if not dir then
    vim.notify("Not an Angular component file", vim.log.levels.WARN)
    return
  end

  local start = 1
  for i, kind in ipairs(KINDS) do
    if kind == current then start = i break end
  end

  -- Walk forward through the ring, skipping files that don't exist.
  for offset = 1, #KINDS - 1 do
    local kind = KINDS[((start - 1 + offset) % #KINDS) + 1]
    local target = resolve(dir, stem, kind)
    if target then
      vim.cmd.edit(vim.fn.fnameescape(target))
      return
    end
  end

  vim.notify("No other files for " .. stem)
end

return M
