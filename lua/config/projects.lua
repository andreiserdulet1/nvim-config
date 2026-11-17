-- Project switcher.
--
-- Lists every git repo one or two levels under the roots below -- the ones you
-- switched to most recently first, each with its current branch -- then
-- changes Neovim's working directory to it. Because the cwd changes, LSP root
-- detection, the pickers, lazygit, the dev servers (<leader>ns) and Claude all
-- follow you to the new project.
--
-- If you have worked in that project before, its session (open files, splits)
-- is restored; otherwise the file finder opens.

local M = {}

M.roots = { vim.fn.expand("~/projects") }

local RECENT = vim.fn.stdpath("data") .. "/recent_projects"

local function recent()
  local ok, lines = pcall(vim.fn.readfile, RECENT)
  return ok and lines or {}
end

local function remember(dir)
  local list = { dir }
  for _, d in ipairs(recent()) do
    if d ~= dir and #list < 30 then table.insert(list, d) end
  end
  pcall(vim.fn.writefile, list, RECENT)
end

-- Read .git/HEAD rather than shelling out to git once per repo.
local function branch(dir)
  local ok, lines = pcall(vim.fn.readfile, dir .. "/.git/HEAD", "", 1)
  if not ok or not lines[1] then return "" end
  return lines[1]:match("ref: refs/heads/(.+)") or lines[1]:sub(1, 8)
end

local function find_projects()
  local projects = {}
  for _, root in ipairs(M.roots) do
    if vim.fn.isdirectory(root) == 1 then
      -- Depth 3 covers both ~/projects/<repo> and ~/projects/team-orange/<repo>.
      local out = vim.fn.systemlist({
        "find", root, "-maxdepth", "3", "-name", ".git", "-not", "-path", "*/node_modules/*",
      })
      for _, gitdir in ipairs(out) do
        table.insert(projects, vim.fn.fnamemodify(gitdir, ":h"))
      end
    end
  end

  local rank = {}
  for i, d in ipairs(recent()) do rank[d] = i end
  table.sort(projects, function(a, b)
    local ra, rb = rank[a] or math.huge, rank[b] or math.huge
    if ra ~= rb then return ra < rb end
    return a < b
  end)
  return projects
end

--- Switch to `dir`: cd, then restore its session or open the finder.
function M.open(dir)
  local ok, persistence = pcall(require, "persistence")
  -- Save the project you are leaving while the cwd still says which one it is.
  if ok then pcall(persistence.save) end

  vim.cmd.cd(dir)
  remember(dir)
  vim.notify("Project: " .. vim.fs.basename(dir) .. "  (" .. branch(dir) .. ")")

  local session = ok and persistence.current and persistence.current() or nil
  if session and vim.uv.fs_stat(session) then
    -- Close the old project's files (unsaved ones stay), never terminals:
    -- dev servers and Claude keep running across a switch.
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].buflisted and vim.bo[b].buftype == "" and not vim.bo[b].modified then
        pcall(vim.api.nvim_buf_delete, b, {})
      end
    end
    persistence.load()
  else
    Snacks.picker.files({ cwd = dir })
  end
end

--- Pick a project and hand its path to `cb` (for compare.lua, project tabs).
function M.choose(prompt, cb)
  local projects = find_projects()
  local home = vim.fn.expand("~")
  vim.ui.select(projects, {
    prompt = prompt,
    format_item = function(path)
      return string.format("%-50s %s", (path:gsub("^" .. vim.pesc(home), "~")), branch(path))
    end,
  }, function(choice) if choice then cb(choice) end end)
end

function M.pick()
  local projects = find_projects()
  if #projects == 0 then
    vim.notify("No git projects found under " .. table.concat(M.roots, ", "), vim.log.levels.WARN)
    return
  end

  local home = vim.fn.expand("~")
  vim.ui.select(projects, {
    prompt = "Switch project",
    format_item = function(path)
      return string.format("%-50s %s", (path:gsub("^" .. vim.pesc(home), "~")), branch(path))
    end,
  }, function(choice)
    if choice then M.open(choice) end
  end)
end

return M
