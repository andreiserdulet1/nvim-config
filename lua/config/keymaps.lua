-- Keymaps that don't belong to a specific plugin.
-- Plugin-owned keymaps live next to their plugin in lua/plugins/*.lua.
local map = vim.keymap.set

-- The cheatsheet, and the palette of every command ---------------------------
map("n", "<leader>?", function() require("config.cheatsheet").open() end,
  { desc = "Cheatsheet" })
map("n", "<C-p>", function() require("config.palette").open() end, { desc = "Command palette" })
map("n", "<leader>P", function() require("config.palette").open() end, { desc = "Command palette" })

-- The full write-up. This is the README in the repo this config lives in, so
-- it moves with the config instead of pointing at a link that will rot.
map("n", "<leader>gu", function()
  vim.ui.open("https://github.com/andreiserdulet1/nvim-config#readme")
end, { desc = "Open the web guide" })

-- Theme: Graphite, light or dark. Persists across restarts.
map("n", "<leader>ut", function() require("config.theme").toggle_background() end,
  { desc = "Toggle light / dark" })

-- Colour swatches in CSS/SCSS are native in Neovim 0.12: cssls advertises
-- colorProvider and vim.lsp.document_color renders the swatches, on by
-- default. No plugin needed -- this just makes it toggleable.
map("n", "<leader>uc", function()
  local on = vim.lsp.document_color.is_enabled({ bufnr = 0 })
  vim.lsp.document_color.enable(not on, { bufnr = 0 })
  vim.notify("Colour swatches: " .. (on and "off" or "on"))
end, { desc = "Toggle colour swatches" })

-- CSV table view ------------------------------------------------------------
map("n", "<leader>uv", "<cmd>CsvViewToggle display_mode=border<cr>",
  { desc = "Toggle CSV table view" })

-- Header treatment is per file: the locale exports have no header row, but
-- duplicate.csv and allcardsfile.csv do. This flips it for the current buffer.
-- Unset means off, which is what the locale exports want.
map("n", "<leader>uh", function()
  if vim.bo.filetype:match("csv") == nil and vim.bo.filetype ~= "tsv" then
    vim.notify("Not a CSV buffer", vim.log.levels.WARN)
    return
  end
  local on = vim.b.csv_header_on == true
  vim.b.csv_header_on = not on
  vim.cmd("CsvViewDisable")
  vim.cmd("CsvViewEnable display_mode=border header_lnum=" .. (on and "false" or "1"))
  vim.notify("CSV header row: " .. (on and "off" or "line 1"))
end, { desc = "Toggle CSV header row" })

-- Angular: jump between a component's .ts / .html / .scss / .spec.ts ---------
local component = function(kind)
  return function() require("config.component").open(kind) end
end
map("n", "<leader>ot", component("ts"), { desc = "Component: TypeScript" })
map("n", "<leader>oh", component("html"), { desc = "Component: template" })
map("n", "<leader>os", component("style"), { desc = "Component: styles" })
map("n", "<leader>op", component("spec"), { desc = "Component: spec" })
map("n", "<leader>oo", function() require("config.component").cycle() end,
  { desc = "Component: cycle files" })
map("n", "<leader>or", function() require("config.related").pick() end,
  { desc = "Related: route, module, store, usages" })

-- Run and test this project --------------------------------------------------
local scripts = function(fn, ...)
  local args = { ... }
  return function() require("config.scripts")[fn](unpack(args)) end
end
map("n", "<leader>nr", scripts("pick"), { desc = "Pick a package.json script" })
map("n", "<leader>nt", scripts("test_file"), { desc = "Test this component" })
map("n", "<leader>na", scripts("test_all", false), { desc = "Test everything (once)" })
map("n", "<leader>nw", scripts("test_all", true), { desc = "Test everything (watch)" })
map("n", "<leader>nl", scripts("run", "lint"), { desc = "Lint" })

-- Single tests, results in the gutter, coverage. Clicking ▶ does the same.
-- See config/tests.lua.
local tst = function(fn, ...)
  local args = { ... }
  return function() require("config.tests")[fn](unpack(args)) end
end
map("n", "<leader>nT", tst("run_nearest"), { desc = "Run the test under the cursor" })
map("n", "<leader>nF", tst("run_file"), { desc = "Run this spec (marks ✓ / ✗)" })
map("n", "<leader>n.", tst("rerun"), { desc = "Run the last spec again" })
map("n", "<leader>nf", tst("output"), { desc = "Last test run's output" })
map("n", "<leader>nC", tst("run_coverage"), { desc = "Run this spec with coverage" })
map("n", "<leader>uC", tst("coverage_show"), { desc = "Toggle coverage colours" })
map("n", "<leader>aF", tst("send_failure"), { desc = "Send the failing test to Claude" })

-- Dev servers: this project's start + wiremock, optionally inside shell-ui.
-- Shown in the statusline; click it for the same menu. See config/services.lua.
local svc = function(fn, ...)
  local args = { ... }
  return function() require("config.services")[fn](unpack(args)) end
end
map("n", "<leader>ns", svc("start"), { desc = "Start project (start + wiremock)" })
map("n", "<leader>nS", svc("start_with_shell"), { desc = "Start inside shell-ui (pick branch)" })
map("n", "<leader>nx", svc("stop"), { desc = "Stop all dev servers" })
map("n", "<leader>nX", svc("stop_pick"), { desc = "Stop one dev server" })
map("n", "<leader>nR", svc("restart"), { desc = "Restart a dev server" })
map("n", "<leader>nv", svc("logs"), { desc = "Show dev server output" })
map("n", "<leader>nn", svc("menu"), { desc = "Dev servers menu" })

-- GitHub Actions -----------------------------------------------------------
-- Reading runs is unguarded; dispatching always confirms, and anything aimed
-- at prod has to be typed out. See lua/config/actions.lua.
local acts = function(fn, ...)
  local args = { ... }
  return function() require("config.actions")[fn](unpack(args)) end
end
map("n", "<leader>Al", acts("list"), { desc = "Workflow runs" })
map("n", "<leader>Ao", acts("logs"), { desc = "Logs of the latest run" })
map("n", "<leader>Af", acts("logs", nil, true), { desc = "Failed steps of the latest run" })
map("n", "<leader>Aw", acts("watch"), { desc = "Watch the running workflow" })
map("n", "<leader>Ar", acts("rerun"), { desc = "Re-run failed jobs" })
map("n", "<leader>Ad", acts("dispatch"), { desc = "Dispatch a workflow (confirms)" })

-- Pull requests: viewing and creating happen in the browser, where the form is.
map("n", "<leader>pp", acts("pr_view"), { desc = "PR for this branch (browser)" })
map("n", "<leader>pc", acts("pr_create"), { desc = "Create a PR (browser)" })
map("n", "<leader>pk", acts("pr_checks"), { desc = "Checks on this branch's PR" })

-- Jira ----------------------------------------------------------------------
-- The sprint, the board and the four things that interrupt coding: move,
-- assign, comment, open. Everything shells out to the `jira` CLI, whose API
-- token comes from the macOS Keychain. See lua/config/jira.lua.
--
-- The keys that act on "this issue" resolve it from the branch name first, so
-- on a branch called feature/AWIN-1841-rounding they need no argument at all.
local jira = function(fn)
  return function() require("config.jira")[fn]() end
end
local on_current = function(fn)
  return function()
    local j = require("config.jira")
    j.current(function(key) j[fn](key) end)
  end
end
map("n", "<leader>jB", jira("switch"), { desc = "Switch board / project (or all of Awin)" })
map("n", "<leader>js", jira("sprint"), { desc = "Current sprint" })
map("n", "<leader>jb", jira("board"), { desc = "Board (pick a column)" })
map("n", "<leader>jm", jira("mine"), { desc = "My open issues" })
map("n", "<leader>jf", jira("search"), { desc = "Search issues" })
map("n", "<leader>jj", jira("tui"), { desc = "jira-cli explorer (float)" })
map("n", "<leader>jv", on_current("view"), { desc = "View this issue" })
map("n", "<leader>jt", on_current("move"), { desc = "Move this issue" })
map("n", "<leader>ja", on_current("assign"), { desc = "Assign this issue" })
map("n", "<leader>jc", on_current("comment"), { desc = "Comment on this issue" })
map("n", "<leader>jo", on_current("open"), { desc = "Open this issue in the browser" })

-- Angular CLI ---------------------------------------------------------------
-- <leader>ng is a prefix only, never a leaf: a key that is both an action and
-- a prefix makes you wait out the timeout every time you use the action.
local ng = function(schematic)
  return function() require("config.angular").generate(schematic) end
end
map("n", "<leader>ngg", function() require("config.angular").generate_pick() end,
  { desc = "ng generate (pick a schematic)" })
map("n", "<leader>ngc", ng("component"), { desc = "ng generate component" })
map("n", "<leader>ngs", ng("service"), { desc = "ng generate service" })
map("n", "<leader>ngp", ng("pipe"), { desc = "ng generate pipe" })
map("n", "<leader>ngd", ng("directive"), { desc = "ng generate directive" })
map("n", "<leader>ngu", ng("guard"), { desc = "ng generate guard" })
map("n", "<leader>ngx", function() require("config.angular").palette() end,
  { desc = "ng command palette" })

-- Copying ------------------------------------------------------------------
-- See config/copy.lua: paths, GitHub links, snippets, imports, history.
local cp = function(fn) return function() require("config.copy")[fn]() end end
-- <leader>y is a prefix only; a key that is both waits out the timeout.
map({ "n", "x" }, "<leader>yy", cp("menu"), { desc = "Copy… (path, link, snippet)" })
map({ "n", "x" }, "<leader>yg", cp("github"), { desc = "Copy GitHub link" })
map({ "n", "x" }, "<leader>yr", cp("path_line"), { desc = "Copy path:line" })
map({ "n", "x" }, "<leader>ym", cp("markdown"), { desc = "Copy as Markdown block" })
map("n", "<leader>yp", cp("relative"), { desc = "Copy relative path" })
map("n", "<leader>yi", cp("import"), { desc = "Copy import line" })
map("n", "<leader>fy", cp("history"), { desc = "Clipboard history" })
map("n", "<leader>uy", function() require("config.copy").toggle_copy_on_select() end,
  { desc = "Toggle copy on mouse select" })

-- Git, JetBrains-style: one menu plus direct keys. See config/vcs.lua.
local vcs = function(fn, ...)
  local args = { ... }
  return function() require("config.vcs")[fn](unpack(args)) end
end
map("n", "<leader>gv", vcs("menu"), { desc = "Git menu (add, rollback, stash, commit…)" })
map("n", "<leader>gA", vcs("add"), { desc = "Add this file" })
map("n", "<leader>gR", vcs("rollback"), { desc = "Rollback this file" })
map("n", "<leader>gk", vcs("commit", false), { desc = "Commit…" })
map("n", "<leader>gK", vcs("commit", true), { desc = "Commit and push…" })
map("n", "<leader>gp", vcs("push"), { desc = "Push" })
map("n", "<leader>gP", vcs("pull"), { desc = "Pull (rebase)" })
map("n", "<leader>gn", vcs("branches"), { desc = "Branches (switch / new)" })
map("n", "<leader>gS", vcs("stash"), { desc = "Stash changes" })
map("n", "<leader>gU", vcs("unstash"), { desc = "Unstash (pop / apply / drop)" })
map("n", "<leader>gz", vcs("undo_commit"), { desc = "Undo last commit (keep changes)" })

-- Compare: before / after, and two repos at once ----------------------------
-- See config/compare.lua. Every comparison opens in its own tab.
local cmp = function(fn) return function() require("config.compare")[fn]() end end
map("n", "<leader>Dd", cmp("menu"), { desc = "Compare this file with…" })
map("n", "<leader>Dr", cmp("with_other_repo"), { desc = "…the same file in another repo" })
map("n", "<leader>Db", cmp("with_branch"), { desc = "…another branch" })
map("n", "<leader>Do", cmp("with_buffer"), { desc = "…another open file" })
map({ "n", "x" }, "<leader>Dc", cmp("with_clipboard"), { desc = "…the clipboard" })
map("n", "<leader>DF", cmp("folders"), { desc = "Compare two repos / folders" })
map("n", "<leader>Dt", cmp("project_tab"), { desc = "Open another repo in a new tab" })
map("n", "<leader>Ds", cmp("project_split"), { desc = "Open another repo beside this one" })
map("n", "<leader>Dq", cmp("close"), { desc = "Close the comparison" })

-- Saving / quitting ---------------------------------------------------------
map({ "n", "i", "v" }, "<C-s>", "<cmd>write<cr><esc>", { desc = "Save file" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- Escape clears extra cursors first, otherwise the search highlight.
-- package.loaded is checked rather than require()d so pressing Esc doesn't
-- force multicursor to load on a session where it was never used.
map("n", "<Esc>", function()
  local mc = package.loaded["multicursor-nvim"]
  if mc and mc.hasCursors() then
    mc.clearCursors()
  else
    vim.cmd("nohlsearch")
  end
end, { desc = "Clear cursors / search highlight" })

-- Window navigation ---------------------------------------------------------
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "<leader>|", "<C-w>v", { desc = "Split vertical" })
map("n", "<leader>-", "<C-w>s", { desc = "Split horizontal" })
map("n", "<leader>wd", "<C-w>c", { desc = "Close window" })

-- More window management ----------------------------------------------------
map("n", "<leader>wo", "<C-w>o", { desc = "Close other windows" })
map("n", "<leader>w=", "<C-w>=", { desc = "Balance windows" })
map("n", "<leader>wm", function()
  -- Maximise the current split, or restore the previous layout if already
  -- maximised. Handy for reading one file in a busy layout.
  if vim.t.maximized then
    vim.cmd("wincmd =")
    vim.t.maximized = false
  else
    vim.cmd("wincmd _")
    vim.cmd("wincmd |")
    vim.t.maximized = true
  end
end, { desc = "Maximise / restore window" })

-- Resize windows with arrows ------------------------------------------------
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase width" })

-- Buffers -------------------------------------------------------------------
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Last buffer" })

-- Move lines up/down (respects indentation) ---------------------------------
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Stay in visual mode when indenting ----------------------------------------
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Keep the cursor centred when jumping around --------------------------------
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Diagnostics ---------------------------------------------------------------
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Prev diagnostic" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- Quickfix -------------------------------------------------------------------
-- conflicts.lua fills this list, grug-far sends search results to it and
-- <leader>xq opens it in Trouble -- three ways in and, until now, no way to
-- walk it. `cnext` past the last entry is an error rather than a wrap, so
-- catch that and go round.
local function qf_step(forward)
  return function()
    if vim.tbl_isempty(vim.fn.getqflist()) then
      vim.notify("Quickfix list is empty")
      return
    end
    if not pcall(vim.cmd, forward and "cnext" or "cprev") then
      vim.cmd(forward and "cfirst" or "clast")
    end
  end
end
map("n", "]q", qf_step(true), { desc = "Next quickfix" })
map("n", "[q", qf_step(false), { desc = "Prev quickfix" })

-- Terminal mode --------------------------------------------------------------
map("t", "<C-/>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "<C-_>", "<C-\\><C-n>", { desc = "Exit terminal mode (tmux)" })

-- Move straight out of a terminal into an adjacent split, without having to
-- leave terminal mode first. The one exception is the lazygit float, which
-- wants <C-j>/<C-k>/<C-l> for itself -- plugins/git.lua maps them back,
-- buffer-locally, on that terminal only.
map("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Window left" })
map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Window down" })
map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Window up" })
map("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Window right" })

-- Close-with-q for the read-only windows that otherwise strand you ----------
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "help", "man", "qf", "checkhealth", "lspinfo", "startuptime",
    "notify", "query", "dap-float", "gitsigns-blame", "fugitive",
  },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>",
      { buffer = ev.buf, silent = true, nowait = true, desc = "Close this window" })
  end,
})
