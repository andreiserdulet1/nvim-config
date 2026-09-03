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
      { "<leader>bd", "Close this buffer" },
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
    "CLAUDE & TERMINAL",
    {
      { "<leader>ac", "Toggle Claude" },
      { "<leader>as", "Send the selected lines to Claude (visual mode)" },
      { "<leader>ab", "Add this file to Claude's context" },
      { "<leader>aa", "Accept Claude's proposed edit" },
      { "<leader>ad", "Reject Claude's proposed edit" },
      { "<leader>tt", "Floating terminal" },
      { "<leader>tn", "Terminal at the project root" },
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
      { "<C-s>", "Save" },
      { "<Esc>", "Clear search highlight" },
      { "<leader>qq", "Quit Neovim" },
      { "<leader>ut", "Switch between the light and dark palette" },
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
