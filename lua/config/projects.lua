-- Project switcher.
--
-- Lists every git repo one or two levels under the roots below, lets you pick
-- one, then changes Neovim's working directory to it and opens the file
-- finder. Because the cwd changes, LSP root detection, Telescope, lazygit and
-- Claude all follow you to the new project.

local M = {}

M.roots = { vim.fn.expand("~/projects") }

local function find_projects()
  local projects = {}
  for _, root in ipairs(M.roots) do
    if vim.fn.isdirectory(root) == 1 then
      -- Depth 2 covers both ~/projects/<repo> and ~/projects/team-orange/<repo>.
      local out = vim.fn.systemlist({
        "find", root, "-maxdepth", "3", "-name", ".git", "-not", "-path", "*/node_modules/*",
      })
      for _, gitdir in ipairs(out) do
        local dir = vim.fn.fnamemodify(gitdir, ":h")
        table.insert(projects, dir)
      end
    end
  end
  table.sort(projects)
  return projects
end

function M.pick()
  local projects = find_projects()
  if #projects == 0 then
    vim.notify("No git projects found under " .. table.concat(M.roots, ", "), vim.log.levels.WARN)
    return
  end

  vim.ui.select(projects, {
    prompt = "Switch project",
    format_item = function(path)
      return path:gsub("^" .. vim.pesc(vim.fn.expand("~")), "~")
    end,
  }, function(choice)
    if not choice then return end
    vim.cmd.cd(choice)
    vim.notify("Project: " .. vim.fn.fnamemodify(choice, ":t"), vim.log.levels.INFO)
    require("telescope.builtin").find_files({ cwd = choice })
  end)
end

return M
