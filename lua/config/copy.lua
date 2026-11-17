-- Copying things that are tedious to type: paths, a GitHub link to the lines
-- you're on, a fenced snippet for Jira or Slack, an Angular import line.
--
-- Everything goes to the system clipboard. Right-click → "Copy…", <leader>yy,
-- or click the file name in the statusline. <leader>fy is this session's
-- clipboard history. In visual mode the selection's
-- lines are used; otherwise the cursor line.

local M = {}

local function put(text, what)
  vim.fn.setreg("+", text)
  local preview = text:gsub("\n.*", " …")
  vim.notify("Copied " .. what .. ": " .. preview:sub(1, 80), vim.log.levels.INFO, { title = "copy" })
end

-- The range is read before any picker opens: once it does, visual mode is gone.
local function range()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local a, b = vim.fn.line("v"), vim.fn.line(".")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
    return math.min(a, b), math.max(a, b)
  end
  local l = vim.fn.line(".")
  return l, l
end

local function root(path)
  return vim.fs.root(path or 0, ".git") or vim.uv.cwd()
end

local function rel(path)
  local r = root(path)
  if path:sub(1, #r + 1) == r .. "/" then return path:sub(#r + 2) end
  return vim.fn.fnamemodify(path, ":~:.")
end

local function lines_suffix(l1, l2)
  return l1 == l2 and (":" .. l1) or (":" .. l1 .. "-" .. l2)
end

---------------------------------------------------------------------------
-- The individual copies
---------------------------------------------------------------------------

function M.relative() put(rel(vim.api.nvim_buf_get_name(0)), "path") end
function M.absolute() put(vim.api.nvim_buf_get_name(0), "absolute path") end
function M.filename() put(vim.fn.expand("%:t"), "file name") end

function M.path_line(l1, l2)
  if not l1 then l1, l2 = range() end
  put(rel(vim.api.nvim_buf_get_name(0)) .. lines_suffix(l1, l2), "reference")
end

--- A fenced Markdown block with the path and lines above it.
function M.markdown(l1, l2)
  if not l1 then l1, l2 = range() end
  local code = table.concat(vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false), "\n")
  local lang = vim.bo.filetype == "typescriptreact" and "tsx" or vim.bo.filetype
  local ref = rel(vim.api.nvim_buf_get_name(0)) .. lines_suffix(l1, l2)
  put(("`%s`\n```%s\n%s\n```"):format(ref, lang, code), "snippet")
end

local function git(args, path)
  local res = vim.system(vim.list_extend({ "git" }, args), { cwd = root(path), text = true }):wait()
  return res.code == 0 and vim.trim(res.stdout or "") or nil
end

--- The GitHub URL for a file or folder, optionally at lines. A permalink to the
--- commit when it is pushed; otherwise that link would 404, so it points at the
--- default branch and says so.
---@return string|nil
function M.github_url(path, l1, l2)
  local r = root(path)
  local target = rel(path)
  if l1 then target = target .. lines_suffix(l1, l2) end
  local sha = git({ "rev-parse", "HEAD" }, path)
  local pushed = sha and git({ "branch", "-r", "--contains", sha }, path) or ""
  local args = { "gh", "browse", target, "--no-browser" }
  if sha and pushed ~= "" then
    table.insert(args, "--commit=" .. sha)
  else
    local base = (git({ "symbolic-ref", "--short", "refs/remotes/origin/HEAD" }, path) or "origin/main")
      :gsub("^origin/", "")
    vim.list_extend(args, { "--branch", base })
    vim.notify("This commit isn't pushed — linking to " .. base .. " instead", vim.log.levels.WARN)
  end
  local res = vim.system(args, { cwd = r, text = true }):wait()
  if res.code ~= 0 then
    vim.notify("gh browse failed:\n" .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
    return nil
  end
  return vim.trim(res.stdout)
end

--- Copy a GitHub link to these lines.
function M.github(l1, l2)
  if not l1 then l1, l2 = range() end
  local url = M.github_url(vim.api.nvim_buf_get_name(0), l1, l2)
  if url then put(url, "GitHub link") end
end

--- Open these lines on GitHub.
function M.open_github(l1, l2)
  if not l1 then l1, l2 = range() end
  local url = M.github_url(vim.api.nvim_buf_get_name(0), l1, l2)
  if url then vim.ui.open(url) end
end

--- Copy a path relative to its repo.
function M.copy_relative(path) put(rel(path), "path") end

--- `import { Name } from '…'` for the symbol under the cursor (or the file's
--- main export), relative to the file you were in before this one -- that is
--- usually where you are about to paste it.
function M.import()
  local file = vim.api.nvim_buf_get_name(0)
  if not file:match("%.tsx?$") then vim.notify("Not a TypeScript file") return end

  local word = vim.fn.expand("<cword>")
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local function exported(name)
    return name ~= "" and text:match("export%s+[%w%s]*[%s]" .. vim.pesc(name) .. "[%s<(:=]") ~= nil
  end
  local name = exported(word) and word
    or text:match("export%s+class%s+([%w_]+)")
    or text:match("export%s+[%w%s]-%s([%w_]+)%s*[<(:={]")
  if not name then vim.notify("No export found in this file") return end

  local target = file:gsub("%.tsx?$", "")
  local from
  local alt = vim.fn.expand("#:p")
  if alt ~= "" and alt:match("%.tsx?$") and alt ~= file then
    from = vim.fs.relpath(vim.fs.dirname(alt), target)
    if from and not from:match("^%.") then from = "./" .. from end
    if not from then
      -- Not below the other file's folder: walk up to a common ancestor.
      local up, dir = "", vim.fs.dirname(alt)
      while dir and dir ~= "/" and not vim.fs.relpath(dir, target) do
        up, dir = up .. "../", vim.fs.dirname(dir)
      end
      from = dir and (up .. vim.fs.relpath(dir, target)) or nil
    end
  end
  from = from or rel(target)
  put(("import { %s } from '%s';"):format(name, from), "import")
end

--- The diagnostic message(s) on the current line.
function M.diagnostic()
  local lnum = vim.fn.line(".") - 1
  local msgs = {}
  for _, d in ipairs(vim.diagnostic.get(0, { lnum = lnum })) do
    table.insert(msgs, d.message .. (d.source and (" (" .. d.source .. ")") or ""))
  end
  if #msgs == 0 then vim.notify("No diagnostic on this line") return end
  put(table.concat(msgs, "\n"), "diagnostic")
end

--- The Jira key in the current branch name (feature/AWIN-1841-x → AWIN-1841).
function M.jira_key()
  local branch = git({ "rev-parse", "--abbrev-ref", "HEAD" }) or ""
  local key = branch:match("(%u[%u%d]+%-%d+)")
  if not key then vim.notify("No Jira key in branch '" .. branch .. "'") return end
  put(key, "Jira key")
end

function M.branch()
  local branch = git({ "rev-parse", "--abbrev-ref", "HEAD" })
  if branch then put(branch, "branch") end
end

---------------------------------------------------------------------------
-- Clipboard history
---------------------------------------------------------------------------

-- The last 50 things you yanked or cut, newest first, for this session.
-- Neovim's numbered registers only keep line-wise deletes; this keeps all.
M.ring = {}

-- Select with the mouse = copied, like a terminal. With mouse=a, iTerm2 hands
-- drags to Neovim, so Cmd+C has no selection of its own to copy; this makes the
-- drag itself copy to the system clipboard (and keeps the selection, so you can
-- still act on it). Cmd+V pastes as normal. <leader>uy turns it off.
vim.g.copy_on_select = true

local function copy_on_release()
  if vim.g.copy_on_select then
    vim.cmd('silent normal! "+ygv')
  end
end

function M.toggle_copy_on_select()
  vim.g.copy_on_select = not vim.g.copy_on_select
  vim.notify("Copy on mouse select: " .. (vim.g.copy_on_select and "on" or "off"))
end

function M.setup()
  vim.keymap.set("x", "<LeftRelease>", copy_on_release, { desc = "Mouse selection → clipboard" })
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("config_yank_ring", { clear = true }),
    callback = function()
      local ev = vim.v.event
      local text = table.concat(ev.regcontents, "\n")
      if vim.trim(text) == "" then return end
      for i, entry in ipairs(M.ring) do
        if entry.text == text then table.remove(M.ring, i) break end
      end
      table.insert(M.ring, 1, { text = text, regtype = ev.regtype, ft = vim.bo.filetype })
      if #M.ring > 50 then table.remove(M.ring) end
    end,
  })
end

--- Pick something you copied earlier and paste it after the cursor.
function M.history()
  if #M.ring == 0 then vim.notify("Nothing copied yet this session") return end
  local items = {}
  for i, e in ipairs(M.ring) do
    items[i] = { idx = i, entry = e, text = e.text,
      preview = { text = e.text, ft = e.ft ~= "" and e.ft or "text" } }
  end
  Snacks.picker.pick({
    title = "Clipboard history   <CR> paste  <C-y> copy only",
    items = items,
    format = function(item)
      local first = item.entry.text:gsub("\n.*", " …")
      return { { (first:gsub("^%s+", "")) } }
    end,
    preview = "preview",
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      vim.schedule(function()
        vim.api.nvim_put(vim.split(item.entry.text, "\n"), item.entry.regtype:sub(1, 1) == "V" and "l" or "c", true, true)
      end)
    end,
    actions = {
      copy_only = function(picker, item)
        picker:close()
        if item then put(item.entry.text, "from history") end
      end,
    },
    win = { input = { keys = { ["<C-y>"] = { "copy_only", mode = { "i", "n" } } } } },
  })
end

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------

function M.menu()
  local l1, l2 = range()
  local file = vim.api.nvim_buf_get_name(0)
  local has_file = file ~= "" and vim.bo.buftype == ""
  local items = {}
  local function add(label, fn, cond)
    if cond == false then return end
    table.insert(items, { label = label, run = fn })
  end
  local where = lines_suffix(l1, l2)
  add("GitHub link to line" .. (l1 == l2 and "" or "s") .. " " .. where:sub(2), function() M.github(l1, l2) end, has_file)
  add("Reference  path" .. where, function() M.path_line(l1, l2) end, has_file)
  add("As a Markdown code block", function() M.markdown(l1, l2) end, has_file)
  add("Relative path", M.relative, has_file)
  add("Absolute path", M.absolute, has_file)
  add("File name", M.filename, has_file)
  add("Import line for this symbol", M.import, has_file and file:match("%.tsx?$") ~= nil)
  add("Diagnostic message", M.diagnostic, #vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 }) > 0)
  add("Jira key from the branch", M.jira_key)
  add("Branch name", M.branch)
  add("Paste from clipboard history…", M.history)

  vim.ui.select(items, {
    prompt = "Copy",
    format_item = function(i) return i.label end,
  }, function(i) if i then i.run() end end)
end

return M
