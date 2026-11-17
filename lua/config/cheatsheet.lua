-- The <leader>? cheatsheet.
--
-- This table is the single source of truth for the keymap reference. Add a
-- keymap in keymaps.lua or a plugin spec, then add one line here and it shows
-- up in the popup. Keep it in sync — it is the thing you will actually read.

local M = {}

M.sections = {
  {
    "FIND & NAVIGATE",
    {
      { "<leader><space>", "Find file in project" },
      { "<leader>fg", "Live grep across the project" },
      { "<leader>fw", "Grep the word under the cursor" },
      { "<leader>fb", "Switch between open buffers" },
      { "<leader>fr", "Recently opened files" },
      { "<leader>fs", "Symbols in this file (classes, methods)" },
      { "<leader>fS", "Symbols across the whole project" },
      { "<leader>fh", "Search Neovim's help" },
      { "<leader>fk", "Search all keymaps" },
      { "<leader>e", "Toggle the file tree" },
      { "<leader>fe", "Reveal the current file in the tree" },
      { "s", "Flash: jump to any word on screen" },
      { "<leader>fp", "Switch project (recent first; restores its session)" },
      { "<C-p>", "Command palette: every action in this config" },
    },
  },
  {
    "MOUSE",
    {
      { "click ☰", "Statusline: every command, searchable  <- start here" },
      { "drag to select", "Copies to the clipboard (like a terminal)" },
      { "Cmd+V", "Pastes, in text and in terminals" },
      { "right click", "…also has Copy / Paste / Copy… / Paste from history" },
      { "<leader>uy", "Turn copy-on-select off / on" },
      { "click ▶ Run", "Statusline: start / stop / view dev servers" },
      { "click ✦ Claude", "Statusline: show / hide Claude (right-click: move it)" },
      { "click ⚙ CI", "Statusline: this branch's workflow runs" },
      { "right click", "Copy…, code action, rename, usages, hunks, Claude," },
      { "", "test, go to template/styles/spec, comment, GitHub" },
      { "on a selection", "Right-click to search the project for that text" },
      { "<C-click>", "Go to definition, through the LSP" },
      { "right click a file", "Tree: new, rename, delete, test, search here," },
      { "", "terminal here, ng generate here, Claude, GitHub" },
      { "right click a tab", "Close, close others, pin, copy path, GitHub, history" },
      { "right click a term", "Paste, copy / send output to Claude, move, hide" },
      { "terminal buttons", "⇱ ⬓ ◨ move a terminal or Claude, ✕ hides it" },
      { "on the dashboard", "Double click an entry to run it" },
      { "double click", "In the tree: open the file. In text: select the word" },
      { "triple click", "Select the line" },
      { "click a crumb", "Breadcrumbs: open that level as a dropdown" },
      { "click the branch", "Statusline: opens lazygit" },
      { "click a diagnostic", "Statusline: opens the Trouble list" },
      { "click the diff", "Statusline: opens diffview" },
      { "drag a separator", "Resize the split" },
      { "the fold column", "Click a marker to fold or unfold" },
      { "middle click a tab", "Close that buffer, keeping the split" },
      { "in a picker", "Click a result to select it, double click to open it" },
      { "in a list", "Double click in Trouble, diffview, quickfix or undotree" },
    },
  },
  {
    "COPY  (also right-click → Copy…, or click the file name in the statusline)",
    {
      { "<leader>yy", "Copy… — pick what (works on a selection too)" },
      { "<leader>yg", "GitHub permalink to this line / selection" },
      { "<leader>yr", "path:line reference, e.g. src/app/x.ts:12-20" },
      { "<leader>ym", "Selection as a Markdown code block with its path" },
      { "<leader>yp", "Relative path" },
      { "<leader>yi", "import { Symbol } from '…' — relative to the last file" },
      { "<leader>fy", "Clipboard history: <CR> pastes, <C-y> copies" },
    },
  },
  {
    "COMPARE & TWO REPOS  (each comparison opens in its own tab)",
    {
      { "<leader>Dd", "Compare this file with… (pick)" },
      { "<leader>Dr", "…the same path in another repo (migration)" },
      { "<leader>Db", "…another branch, tag or commit" },
      { "<leader>Do", "…another open file" },
      { "<leader>Dc", "…the clipboard (selection in visual mode)" },
      { "<leader>DF", "Two repos / folders: every differing file, with" },
      { "", "a diff preview; <CR> opens it, <leader>fc goes back" },
      { "<leader>Dt", "Open another repo in a new tab (its own cwd:" },
      { "", "pickers, grep, terminals, <leader>ns work there)" },
      { "<leader>Ds", "Open another repo in a split beside this one" },
      { "<leader>Dq", "Close the comparison  (or click ✕ on its bar)" },
      { "]c / [c", "Next / previous change in a diff" },
      { "do / dp", "Take the other side's change / give yours" },
      { "gt / gT", "Next / previous tab" },
    },
  },
  {
    "BUFFERS (your tabs along the top)",
    {
      { "<S-h> / <S-l>", "Previous / next buffer" },
      { "<leader>bd", "Close this buffer (keeps the split)" },
      { "<leader>bD", "Close it and discard changes" },
      { "<leader>bo", "Close every other buffer" },
      { "<leader>bp", "Pin buffer so it stays put" },
      { "<leader>`", "Jump back to the last buffer" },
      { "<leader>1 .. 9", "Jump straight to buffer 1-9" },
    },
  },
  {
    "CODE & LSP",
    {
      { "gd", "Go to definition" },
      { "gr", "Find all references" },
      { "gi", "Go to implementation" },
      { "gy", "Go to type definition" },
      { "K", "Hover documentation" },
      { "]] / [[", "Next / previous use of the symbol under the cursor" },
      { "<leader>ca", "Code actions (quick fixes, imports)" },
      { "<leader>cr", "Rename symbol everywhere" },
      { "<leader>cf", "ESLint: fix everything fixable" },
      { "<leader>cI", "Organize imports" },
      { "<leader>cR", "Remove unused imports" },
      { "<leader>cF", "Format this file now" },
      { "<leader>ci", "Toggle inlay hints (inferred types)" },
      { "[d / ]d", "Previous / next diagnostic" },
      { "[q / ]q", "Previous / next quickfix entry (wraps)" },
      { "<leader>xx", "Diagnostics list for this file" },
      { "<leader>xX", "Diagnostics list for the project" },
      { "<leader>xt", "TODO / FIXME list" },
      { "<leader>uf", "Toggle format-on-save for this session" },
    },
  },
  {
    "ANGULAR",
    {
      { "<leader>ot", "Go to the component's .ts" },
      { "<leader>oh", "Go to its .html template" },
      { "<leader>os", "Go to its .scss styles" },
      { "<leader>op", "Go to its .spec.ts" },
      { "<leader>or", "Related: the route, module, store, templates, usages" },
      { "<leader>oo", "Cycle through whichever of those exist" },
      { "<leader>nr", "Run a script from this repo's package.json" },
    },
  },
  {
    "ANGULAR CLI",
    {
      { "<leader>ngg", "ng generate — pick from every schematic" },
      { "<leader>ngc", "ng generate component" },
      { "<leader>ngs", "ng generate service" },
      { "<leader>ngp", "ng generate pipe" },
      { "<leader>ngd", "ng generate directive" },
      { "<leader>ngu", "ng generate guard" },
      { "<leader>ngx", "Any other ng command (version, update, add, cache)" },
      { "", "Names prefill from the folder you're in;" },
      { "", "every generate previews the files first." },
    },
  },
  {
    "DEV SERVERS  (any repo in ~/projects; also the ▶ button in the statusline)",
    {
      { "<leader>ns", "Start this project: yarn start + yarn wiremock" },
      { "<leader>nS", "Start it inside shell-ui — pick shell-ui's branch;" },
      { "", "switches it in place (refuses if dirty), runs" },
      { "", "yarn install only if yarn.lock changed, and" },
      { "", "uses shell-ui's wiremock instead of the project's" },
      { "<leader>nx", "Stop everything  (right-click ▶ does the same)" },
      { "<leader>nX", "Stop one" },
      { "<leader>nR", "Restart one" },
      { "<leader>nv", "Show a server's output" },
      { "<leader>ae", "Send a server's output to Claude to fix" },
      { "<leader>nn", "All of the above as a menu  (left-click ▶)" },
    },
  },
  {
    "TESTS IN THE GUTTER  (a ▶ beside every describe / it in a spec)",
    {
      { "click ▶", "Run that test (or describe) on its own" },
      { "<leader>nT", "Run the test under the cursor" },
      { "<leader>nF", "Run this spec — marks turn ✓ / ✗" },
      { "<leader>n.", "Run the last spec again" },
      { "<leader>nf", "Show the last run's output" },
      { "<leader>aF", "Send the failing test (on a ✗ line) to Claude" },
      { "<leader>nC", "Run this spec with coverage: line numbers turn" },
      { "", "green (ran) / red (never ran) in the files it covers" },
      { "<leader>uC", "Toggle the coverage colours" },
    },
  },
  {
    "RUN & TEST",
    {
      { "<leader>nt", "Test just this component" },
      { "<leader>na", "Run every test once" },
      { "<leader>nw", "Run every test, watching" },
      { "<leader>nl", "Lint" },
      { "<leader>nr", "Pick any package.json script" },
    },
  },
  {
    "MULTI-CURSOR & REPLACE",
    {
      { "<C-n>", "Cursor at the next match of this word" },
      { "<C-p>", "Skip this match (while there are extra cursors)" },
      { "<leader>ma", "A cursor on every match in the file" },
      { "<leader>mj / mk", "Add a cursor below / above" },
      { "<C-LeftMouse>", "Add a cursor where you click" },
      { "<Esc>", "Clear the extra cursors" },
      { "<leader>sr", "Search & replace across the project" },
      { "<leader>sw", "...prefilled with the word under the cursor" },
      { "<leader>sf", "...limited to this file" },
    },
  },
  {
    "GITHUB ACTIONS",
    {
      { "<leader>Al", "Workflow runs (pick one, then act on it)" },
      { "<leader>Ao", "Logs of the latest run" },
      { "<leader>Af", "Failed steps only" },
      { "<leader>Aw", "Watch the running workflow live" },
      { "<leader>Ar", "Re-run the failed jobs" },
      { "<leader>Ad", "Dispatch a workflow — always confirms;" },
      { "", "anything targeting prod must be typed out" },
    },
  },
  {
    "PULL REQUESTS",
    {
      { "<leader>pp", "The PR for this branch, in the browser" },
      { "<leader>pc", "Create a PR for this branch, in the browser" },
      { "<leader>pk", "Checks on this branch's PR" },
    },
  },
  {
    "JIRA",
    {
      { "<leader>jB", "Switch board / project — any Awin team, or" },
      { "", "All of Awin (search everywhere); remembered" },
      { "<leader>js", "Current sprint of that board" },
      { "<leader>jb", "Board — pick a column, then an issue" },
      { "<leader>jm", "My open issues, across every project" },
      { "<leader>jf", "Search issues — or type a key to jump" },
      { "", "AR-991, ar-991, or just 991, from any project" },
      { "", "Anything else searches summary, description" },
      { "", "and comments; round finds rounding" },
      { "", "The list previews the issue as you move:" },
      { "", "description, comments, sprint, points, epic" },
      { "", "In the list: <CR> actions, ^t move, ^a assign," },
      { "", "^c comment, ^o browser, ^v full view" },
      { "<leader>jv", "Read this branch's issue in a buffer" },
      { "<leader>jt", "Move it to another column" },
      { "<leader>ja", "Assign it" },
      { "<leader>jc", "Comment on it  (<C-s> posts)" },
      { "<leader>jo", "Open it in the browser" },
      { "<leader>jj", "The raw jira-cli explorer" },
    },
  },
  {
    "GIT, JETBRAINS-STYLE  (right-click → Git…, or right-click the branch)",
    {
      { "<leader>gv", "The git menu: file, change, repo — all of it" },
      { "click a change", "In the gutter: show / stage / rollback it" },
      { "<leader>gA / gR", "Add / rollback this file (asks first)" },
      { "<leader>gk / gK", "Commit… / commit and push…" },
      { "<leader>gp / gP", "Push (sets upstream) / pull (rebase, autostash)" },
      { "<leader>gn", "Branches: switch (offers to stash) or create" },
      { "<leader>gS / gU", "Stash / unstash — pop, apply or drop, with preview" },
      { "<leader>gz", "Undo the last commit, keeping its changes" },
    },
  },
  {
    "GIT",
    {
      { "<leader>gg", "lazygit for this repo  <- the main one" },
      { "<leader>gf", "lazygit history for this file" },
      { "<leader>gb", "Blame the current line" },
      { "<leader>gB", "Blame the whole file" },
      { "<leader>ug", "Toggle inline blame on every line" },
      { "<leader>gd", "Diffview: working tree changes" },
      { "<leader>gm", "Diffview: your branch vs main/master" },
      { "<leader>gH", "Diffview: this file's history" },
      { "<leader>gq", "Close diffview" },
      { "<leader>gl", "lazygit commit log" },
      { "<leader>gc", "Browse commits" },
      { "]h / [h", "Next / previous changed hunk" },
      { "<leader>ghs", "Stage this hunk (again to unstage)" },
      { "<leader>ghr", "Discard this hunk" },
      { "<leader>ghp", "Preview this hunk's diff" },
    },
  },
  {
    "LAZYGIT  (inside the <leader>gg float)",
    {
      { "?", "Every action for this panel, with its key  <- start here" },
      { "click / scroll", "Focus a panel, pick a row, switch its tabs" },
      { "1 .. 5", "Status / Files / Branches / Commits / Stash" },
      { "[ / ]", "Previous / next tab within a panel" },
      { "<space>", "Stage a file, check out a branch, check out a commit" },
      { "<enter>", "Go into it: a branch's commits, a file's hunks" },
      { "c", "Commit what is staged" },
      { "p / P", "Pull / push" },
      { "C", "Copy this commit to cherry-pick (again to un-copy)" },
      { "V", "Paste the copied commits onto the checked-out branch" },
      { "<C-R>", "Forget the copied commits" },
      { "v", "Range select, <S-up> / <S-down> to extend" },
      { "m", "Continue or abort a rebase or cherry-pick in progress" },
      { "z / Z", "Undo / redo the last git action, via the reflog" },
      { "W", "Diff two branches or commits" },
      { "@", "Command log: the git command lazygit just ran" },
      { "+ / _", "Zoom this panel bigger / smaller" },
      { "q", "Back out, then quit" },
    },
  },
  {
    "MERGE CONFLICTS  (all inside the merge view)",
    {
      { "<leader>gx", "Open the 3-pane merge view  <- start here" },
      { "<leader>gX", "List every conflicted file" },
      { "left pane", "Double-click a line: take OURS for that conflict" },
      { "right pane", "Double-click a line: take THEIRS for that conflict" },
      { "middle pane", "Double-click a marker: keep that side  <- easiest" },
      { "right click", "Every choice, for the conflict under the pointer" },
      { "]x / [x", "Next / previous conflict" },
      { "<tab> / <s-tab>", "Next / previous conflicted file" },
      { "<leader>b", "Show the file list (hidden, so the panes get the screen)" },
      { "<leader>co", "Take OURS (what you had, the left pane)" },
      { "<leader>ct", "Take THEIRS (what came in, the right pane)" },
      { "<leader>ca", "Take both sides" },
      { "<leader>cb", "Take the common ancestor" },
      { "dx", "Take neither, delete the region" },
      { "<leader>cO", "Take ours for the WHOLE file" },
      { "<leader>cT", "Take theirs for the whole file" },
      { "<leader>gg", "then stage the file and continue in lazygit" },
    },
  },
  {
    "CLAUDE  (✦ in the statusline: click to toggle, right-click to move)",
    {
      { "<leader>ac", "Show / hide Claude" },
      { "<leader>aC", "Continue the last conversation in this project" },
      { "<leader>ar", "Resume an earlier one — listed by first prompt" },
      { "<leader>an", "New conversation (/clear)" },
      { "<leader>ap", "Put Claude right / bottom / float / left (remembered)" },
      { "<leader>a= / a-", "Grow / shrink its window" },
      { "<leader>aq", "Ask about this line or selection" },
      { "<leader>ax", "Fix the diagnostics on this line or selection" },
      { "<leader>ai", "Explain this line or selection" },
      { "<leader>at", "Write tests for this component" },
      { "<leader>aR", "Review my uncommitted changes" },
      { "<leader>as", "Send the selected lines (visual mode)" },
      { "<leader>ab", "Add this file to the conversation" },
      { "<leader>aa / ad", "Accept / reject Claude's proposed edit" },
    },
  },
  {
    "TERMINAL  (every terminal has ⇱ float ⬓ bottom ◨ right ✕ hide buttons)",
    {
      { "<C-\\>", "Quick terminal toggle" },
      { "<leader>tt", "Floating terminal" },
      { "<leader>th / tv", "Terminal at the bottom / on the right" },
      { "<leader>tm", "Move this terminal: float → bottom → right" },
      { "<leader>tn", "Terminal at the project root (reused)" },
      { "<leader>tl", "List and switch between terminals" },
      { "<leader>t1 .. 3", "Jump to terminal 1-3" },
      { "<leader>tx", "Close this terminal" },
      { "<leader>tX", "Close every terminal (dev servers keep running)" },
      { "<C-/>", "Escape a terminal back to normal mode" },
    },
  },
  {
    "WINDOWS & THE BASICS",
    {
      { "<C-h/j/k/l>", "Move between splits" },
      { "<leader>|", "Split vertically" },
      { "<leader>-", "Split horizontally" },
      { "<leader>wd", "Close this window" },
      { "<leader>wo", "Close every other window" },
      { "<leader>wm", "Maximise / restore this window" },
      { "q", "Closes help, quickfix, checkhealth etc." },
      { "za", "Fold or unfold the block under the cursor" },
      { "zM / zR", "Fold everything / unfold everything" },
      { "z=", "Spelling suggestions (markdown and commit messages)" },
      { "<C-s>", "Save" },
      { "<Esc>", "Clear search highlight" },
      { "<leader>qq", "Quit Neovim" },
      { "<leader>qs", "Restore this project's session" },
      { "<leader>ql", "Restore the last session" },
      { "<leader>;", "Jump via the breadcrumb bar" },
      { "<leader>ut", "Flip light / dark" },
      { "<leader>um", "Toggle markdown rendering" },
      { "<leader>uc", "Toggle colour swatches" },
      { "<leader>uv", "Toggle CSV table view" },
      { "<leader>uh", "Toggle the CSV header row" },
      { "<leader>uu", "Undo history as a tree" },
      { "<leader>?", "This cheatsheet" },
      { "<leader>gu", "Open the full web guide in a browser" },
    },
  },
}

-- Render the sections into a centred, scrollable floating window.
function M.open()
  local lines, highlights = {}, {}
  local pad = "  "

  table.insert(lines, "")
  table.insert(lines, pad .. "NEOVIM CHEATSHEET" .. "   (q or <Esc> to close)")
  table.insert(highlights, { line = #lines - 1, group = "Title" })
  table.insert(lines, "")

  for _, section in ipairs(M.sections) do
    local title, maps = section[1], section[2]
    table.insert(lines, pad .. title)
    table.insert(highlights, { line = #lines - 1, group = "Statement" })
    for _, map in ipairs(maps) do
      table.insert(lines, string.format("%s  %-18s %s", pad, map[1], map[2]))
      table.insert(highlights, { line = #lines - 1, group = "Comment", col = #pad + 20 })
    end
    table.insert(lines, "")
  end

  local width = 0
  for _, l in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(l)) end
  width = math.min(width + 2, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 6)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local ns = vim.api.nvim_create_namespace("cheatsheet")
  for _, h in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(buf, ns, h.line, h.col or 0, {
      end_row = h.line,
      end_col = #(lines[h.line + 1] or ""),
      hl_group = h.group,
    })
  end

  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "cheatsheet"
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Keymaps ",
    title_pos = "center",
  })
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = false

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<cr>", { buffer = buf, nowait = true, silent = true })
  end
end

return M
