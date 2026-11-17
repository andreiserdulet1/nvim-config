-- Related files: where this component or service is wired in.
--
-- <leader>or (or right-click → Related files…) finds every place the file's
-- exports -- and, for a component, its selector -- are used, and labels each
-- one: the ROUTE that loads it, the MODULE that declares it, the STORE files
-- (actions, reducer, effects, selectors, facade, signal store), the TEMPLATES
-- that render it, its SPEC, and every other usage. Pick one to jump there;
-- the preview shows the line in context.

local M = {}

local KINDS = {
  { "route", { "routes%.ts$", "routing%.module%.ts$", "%.routes%.ts$" } },
  { "module", { "%.module%.ts$" } },
  { "store", { "%.actions%.ts$", "%.reducers?%.ts$", "%.effects%.ts$", "%.selectors%.ts$",
    "%.facade%.ts$", "%.store%.ts$", "%.state%.ts$" } },
  { "spec", { "%.spec%.ts$" } },
  { "template", { "%.html$" } },
}
local ORDER = { route = 1, module = 2, store = 3, template = 4, spec = 5, usage = 6, nearby = 7 }
local HL = { route = "DiagnosticOk", module = "Function", store = "Constant", template = "Special",
  spec = "Comment", usage = "Normal", nearby = "Comment" }

local function kind_of(path)
  for _, k in ipairs(KINDS) do
    for _, pat in ipairs(k[2]) do
      if path:match(pat) then return k[1] end
    end
  end
  return "usage"
end

function M.pick()
  local file = vim.api.nvim_buf_get_name(0)
  -- From a template or stylesheet, look at the component class.
  if not file:match("%.ts$") then
    file = require("config.component").sibling_path("ts", file) or file
  end
  if not file:match("%.ts$") then vim.notify("Not a TypeScript file") return end
  local lines = vim.fn.readfile(file)
  local text = table.concat(lines, "\n")

  local names = {}
  for name in text:gmatch("export%s+[%w%s]-class%s+([%w_]+)") do table.insert(names, name) end
  for name in text:gmatch("export%s+const%s+([%w_]+)") do table.insert(names, name) end
  for name in text:gmatch("export%s+function%s+([%w_]+)") do table.insert(names, name) end
  local selector = text:match("selector:%s*['\"]([^'\"]+)['\"]")
  if #names == 0 and not selector then vim.notify("No exports in this file") return end

  local root = vim.fs.root(file, ".git") or vim.uv.cwd()
  local args = { "rg", "--vimgrep", "--no-heading", "-g", "*.ts", "-g", "*.html",
    "-g", "!node_modules", "-g", "!dist", "-g", "!.angular" }
  for _, n in ipairs(names) do vim.list_extend(args, { "-e", "\\b" .. n .. "\\b" }) end
  if selector then vim.list_extend(args, { "-e", "<" .. selector .. "[\\s>/]" }) end
  table.insert(args, root)
  local res = vim.system(args, { text = true }):wait()

  local items, seen = {}, {}
  local stem = file:gsub("%.ts$", "")
  for line in (res.stdout or ""):gmatch("[^\n]+") do
    local path, l, c, content = line:match("^(.-):(%d+):(%d+):(.*)$")
    -- Skip the file itself and its own template/styles.
    if path and path ~= file and not vim.startswith(path, stem .. ".") then
      local key = path .. ":" .. l
      if not seen[key] then
        seen[key] = true
        table.insert(items, {
          file = path, pos = { tonumber(l), tonumber(c) - 1 }, kind = kind_of(path),
          rel = path:sub(#root + 2), content = vim.trim(content),
        })
      end
    end
  end

  -- Store files beside the component, even if they don't import it by name.
  local dir = vim.fs.dirname(file)
  for name, t in vim.fs.dir(dir) do
    local path = dir .. "/" .. name
    if t == "file" and kind_of(path) == "store" and not seen[path .. ":1"] then
      local already = false
      for _, it in ipairs(items) do if it.file == path then already = true break end end
      if not already then
        table.insert(items, { file = path, pos = { 1, 0 }, kind = "store", rel = path:sub(#root + 2),
          content = "(in the same folder)" })
      end
    end
  end

  if #items == 0 then vim.notify("Nothing else references " .. table.concat(names, ", ")) return end
  table.sort(items, function(a, b)
    if ORDER[a.kind] ~= ORDER[b.kind] then return ORDER[a.kind] < ORDER[b.kind] end
    return a.rel < b.rel
  end)
  for i, it in ipairs(items) do
    it.idx, it.text = i, it.kind .. " " .. it.rel .. " " .. it.content
  end

  Snacks.picker.pick({
    title = "Related to " .. (names[1] or selector),
    items = items,
    preview = "file",
    format = function(item)
      return {
        { ("%-9s"):format(item.kind), HL[item.kind] },
        { item.rel .. ":" .. item.pos[1], "Comment" },
        { "  " .. item.content:sub(1, 80) },
      }
    end,
  })
end

return M
