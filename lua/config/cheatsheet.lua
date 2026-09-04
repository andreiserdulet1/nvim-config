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
      { "<leader>fp", "Switch project (~/projects)" },
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
      { "<leader>ca", "Code actions (quick fixes, imports)" },
      { "<leader>cr", "Rename symbol everywhere" },
      { "<leader>cf", "ESLint: fix everything fixable" },
      { "<leader>cI", "Organize imports" },
      { "<leader>cR", "Remove unused imports" },
      { "<leader>cF", "Format this file now" },
      { "<leader>ci", "Toggle inlay hints (inferred types)" },
      { "[d / ]d", "Previous / next diagnostic" },
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
    "RUN & TEST",
    {
      { "<leader>nt", "Test just this component" },
      { "<leader>na", "Run every test once" },
      { "<leader>nw", "Run every test, watching" },
      { "<leader>ns", "Start the dev server" },
      { "<leader>nl", "Lint" },
      { "<leader>nr", "Pick any package.json script" },
    },
  },
  {
    "DEBUG (Chrome)",
    {
      { "<leader>db", "Toggle a breakpoint" },
      { "<leader>dB", "Breakpoint with a condition" },
      { "<leader>dc", "Start, or continue to the next breakpoint" },
      { "<leader>di", "Step into" },
      { "<leader>do", "Step over" },
      { "<leader>dO", "Step out" },
      { "<leader>du", "Show / hide the debug panels" },
      { "<leader>dw", "Watch the expression under the cursor" },
      { "<leader>dr", "Debug REPL" },
      { "<leader>dt", "Stop debugging" },
    },
  },
  {
    "MULTI-CURSOR & REPLACE",
    {
      { "<C-n>", "Cursor at the next match of this word" },
      { "<C-p>", "Skip this match" },
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
      { "<leader>pl", "PRs in this repo" },
      { "<leader>pp", "The PR for this branch" },
      { "<leader>pr", "Start a review" },
      { "<leader>pR", "Submit the review" },
      { "<leader>pi", "Issues" },
      { "<leader>ps", "Search PRs and issues" },
    },
  },
  {
    "GIT",
    {
      { "<leader>gg", "lazygit for this repo  <- the main one" },
      { "<leader>gf", "lazygit history for this file" },
      { "<leader>gb", "Blame the current line" },
      { "<leader>gB", "Blame the whole file" },
      { "<leader>gd", "Diffview: working tree changes" },
      { "<leader>gm", "Diffview: everything on your branch vs master" },
      { "<leader>gH", "Diffview: this file's history" },
      { "<leader>gq", "Close diffview" },
      { "<leader>gl", "lazygit commit log" },
      { "<leader>gc", "Browse commits" },
      { "]h / [h", "Next / previous changed hunk" },
      { "<leader>ghs", "Stage this hunk" },
      { "<leader>ghr", "Discard this hunk" },
      { "<leader>ghp", "Preview this hunk's diff" },
    },
  },
  {
    "MERGE CONFLICTS",
    {
      { "<leader>gx", "Open the 3-pane merge view  <- start here" },
      { "<leader>gX", "List every conflicted file" },
      { "]x / [x", "Next / previous conflict" },
      { "<leader>co", "Take OURS (what you had)" },
      { "<leader>ct", "Take THEIRS (what came in)" },
      { "<leader>cb", "Take both sides" },
      { "<leader>cn", "Take neither, delete the region" },
      { "<leader>cO", "Take ours for the WHOLE file (merge view)" },
      { "<leader>cT", "Take theirs for the whole file (merge view)" },
      { "<leader>gg", "then stage the file and continue in lazygit" },
    },
  },
  {
    "CLAUDE & TERMINAL",
    {
      { "<leader>ac", "Toggle Claude" },
      { "<leader>as", "Send the selected lines to Claude (visual mode)" },
      { "<leader>ab", "Add this file to Claude's context" },
      { "<leader>aa", "Accept Claude's proposed edit" },
      { "<leader>ad", "Reject Claude's proposed edit" },
      { "<leader>tt", "Floating terminal" },
      { "<leader>tn", "Terminal at the project root" },
      { "<leader>tl", "List and switch between terminals" },
      { "<leader>t1 .. 3", "Jump to terminal 1-3" },
      { "<leader>tx", "Close this terminal" },
      { "<leader>tX", "Close every terminal" },
      { "<C-\\>", "Quick terminal toggle" },
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
      { "<C-s>", "Save" },
      { "<Esc>", "Clear search highlight" },
      { "<leader>qq", "Quit Neovim" },
      { "<leader>qs", "Restore this project's session" },
      { "<leader>ql", "Restore the last session" },
      { "<leader>;", "Jump via the breadcrumb bar" },
      { "<leader>ut", "Flip light / dark for the current theme" },
      { "<leader>uT", "Pick a theme (graphite or tokyonight)" },
      { "<leader>um", "Toggle markdown rendering" },
      { "<leader>uc", "Toggle colour swatches" },
      { "<leader>uv", "Toggle CSV table view" },
      { "<leader>uh", "Toggle the CSV header row" },
      { "<leader>uu", "Undo history as a tree" },
      { "<leader>up", "Motion hints while you type" },
      { "<leader>uH", "Hardtime nagging on / off" },
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
