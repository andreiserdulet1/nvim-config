-- The command palette: every action in this config, searchable, in one list.
--
-- <C-p>, <leader>P, or click ☰ in the statusline. Type a few letters of what
-- you want ("start", "claude", "dispatch") and press Enter or double-click.
-- The key shown beside each entry is how to do it without the palette next
-- time.

local M = {}

local function req(mod, fn, ...)
  local args = { ... }
  return function() require(mod)[fn](unpack(args)) end
end
local function cmd(c) return function() vim.cmd(c) end end

M.items = {
  -- Run
  { "Run", "Start this project (yarn start + wiremock)", "<leader>ns", req("config.services", "start") },
  { "Run", "Start inside shell-ui (pick a branch)", "<leader>nS", req("config.services", "start_with_shell") },
  { "Run", "Stop everything", "<leader>nx", req("config.services", "stop") },
  { "Run", "Stop one service", "<leader>nX", req("config.services", "stop_pick") },
  { "Run", "Restart a service", "<leader>nR", req("config.services", "restart") },
  { "Run", "Show a service's output", "<leader>nv", req("config.services", "logs") },
  { "Run", "Pick any package.json script", "<leader>nr", req("config.scripts", "pick") },
  { "Run", "Test this component", "<leader>nt", req("config.scripts", "test_file") },
  { "Run", "Test everything (once)", "<leader>na", req("config.scripts", "test_all", false) },
  { "Run", "Lint", "<leader>nl", req("config.scripts", "run", "lint") },
  -- Claude
  { "Claude", "Show / hide Claude", "<leader>ac", req("config.claude", "toggle") },
  { "Claude", "Continue the last conversation", "<leader>aC", req("config.claude", "continue") },
  { "Claude", "Resume an earlier conversation", "<leader>ar", req("config.claude", "resume") },
  { "Claude", "New conversation (/clear)", "<leader>an", req("config.claude", "new") },
  { "Claude", "Ask about this line / selection", "<leader>aq", req("config.claude", "ask") },
  { "Claude", "Fix the diagnostics here", "<leader>ax", req("config.claude", "fix") },
  { "Claude", "Explain this line / selection", "<leader>ai", req("config.claude", "explain") },
  { "Claude", "Write tests for this component", "<leader>at", req("config.claude", "spec") },
  { "Claude", "Review my uncommitted changes", "<leader>aR", req("config.claude", "review") },
  { "Claude", "Send a dev server's output", "<leader>ae", req("config.services", "send_to_claude") },
  { "Claude", "Add this file to the conversation", "<leader>ab", cmd("ClaudeCodeAdd %") },
  { "Claude", "Move Claude's window (right/bottom/float/left)", "<leader>ap", req("config.claude", "layout_menu") },
  { "Claude", "Pick the model", "<leader>am", cmd("ClaudeCodeSelectModel") },
  -- Copy
  { "Copy", "Copy… (pick what)", "<leader>yy", req("config.copy", "menu") },
  { "Copy", "GitHub link to this line", "<leader>yg", req("config.copy", "github") },
  { "Copy", "path:line reference", "<leader>yr", req("config.copy", "path_line") },
  { "Copy", "As a Markdown code block", "<leader>ym", req("config.copy", "markdown") },
  { "Copy", "Relative path", "<leader>yp", req("config.copy", "relative") },
  { "Copy", "Import line for this symbol", "<leader>yi", req("config.copy", "import") },
  { "Copy", "Clipboard history (paste)", "<leader>fy", req("config.copy", "history") },
  -- Terminal
  { "Terminal", "Shell at the project root", "<leader>tn", function()
      vim.api.nvim_feedkeys(vim.keycode("<leader>tn"), "m", false)
    end },
  { "Terminal", "Floating terminal", "<leader>tt", cmd("ToggleTerm direction=float") },
  { "Terminal", "Terminal at the bottom", "<leader>th", cmd("ToggleTerm direction=horizontal size=15") },
  { "Terminal", "Terminal on the right", "<leader>tv", cmd("ToggleTerm direction=vertical size=80") },
  { "Terminal", "Move this terminal (float → bottom → right)", "<leader>tm", req("config.layout", "cycle") },
  { "Terminal", "List / switch terminals", "<leader>tl", cmd("TermSelect") },
  -- Git
  { "Git", "lazygit", "<leader>gg", cmd("LazyGit") },
  { "Git", "Diff the working tree", "<leader>gd", cmd("DiffviewOpen") },
  { "Git", "Diff against the default branch", "<leader>gm", function()
      vim.api.nvim_feedkeys(vim.keycode("<leader>gm"), "m", false)
    end },
  { "Git", "File history", "<leader>gH", cmd("DiffviewFileHistory %") },
  { "Git", "Resolve conflicts (3-pane)", "<leader>gx", function()
      vim.api.nvim_feedkeys(vim.keycode("<leader>gx"), "m", false)
    end },
  { "Git", "Pull request for this branch (browser)", "<leader>pp", req("config.actions", "pr_view") },
  { "Git", "Create a pull request (browser)", "<leader>pc", req("config.actions", "pr_create") },
  { "Git", "Checks on this branch's PR", "<leader>pk", req("config.actions", "pr_checks") },
  -- CI
  { "CI", "Workflow runs", "<leader>Al", req("config.actions", "list") },
  { "CI", "Logs of the latest run", "<leader>Ao", req("config.actions", "logs") },
  { "CI", "Failed steps of the latest run", "<leader>Af", req("config.actions", "logs", nil, true) },
  { "CI", "Watch the running workflow", "<leader>Aw", req("config.actions", "watch") },
  { "CI", "Re-run failed jobs", "<leader>Ar", req("config.actions", "rerun") },
  { "CI", "Dispatch a workflow (confirms)", "<leader>Ad", req("config.actions", "dispatch") },
  -- Jira
  { "Jira", "Current sprint", "<leader>js", req("config.jira", "sprint") },
  { "Jira", "Board (pick a column)", "<leader>jb", req("config.jira", "board") },
  { "Jira", "My open issues", "<leader>jm", req("config.jira", "mine") },
  -- Project
  { "Project", "Switch project", "<leader>fp", req("config.projects", "pick") },
  { "Project", "Find file", "<leader><space>", function() Snacks.picker.files() end },
  { "Project", "Grep the project", "<leader>fg", function() Snacks.picker.grep() end },
  { "Project", "Recent files", "<leader>fr", function() Snacks.picker.recent({ filter = { cwd = true } }) end },
  { "Project", "File tree", "<leader>e", cmd("Neotree toggle") },
  { "Project", "Search & replace", "<leader>sr", function()
      vim.api.nvim_feedkeys(vim.keycode("<leader>sr"), "m", false)
    end },
  { "Project", "Restore this project's session", "<leader>qs", function() require("persistence").load() end },
  { "Project", "Diagnostics (project)", "<leader>xX", cmd("Trouble diagnostics toggle") },
  -- Angular
  { "Angular", "ng generate (pick a schematic)", "<leader>ngg", req("config.angular", "generate_pick") },
  { "Angular", "Component: cycle .ts / .html / .scss / .spec", "<leader>oo", req("config.component", "cycle") },
  -- Toggles
  { "Toggle", "Light / dark", "<leader>ut", req("config.theme", "toggle_background") },
  { "Toggle", "Cheatsheet", "<leader>?", req("config.cheatsheet", "open") },
}

function M.open()
  local items = {}
  for i, it in ipairs(M.items) do
    items[i] = { idx = i, group = it[1], label = it[2], key = it[3], run = it[4],
      text = it[1] .. " " .. it[2] .. " " .. it[3] }
  end
  Snacks.picker.pick({
    title = "Commands",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return {
        { ("%-9s"):format(item.group), "Comment" },
        { ("%-52s"):format(item.label) },
        { item.key:gsub("<leader>", "␣"), "Special" },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(item.run) end
    end,
  })
end

return M
