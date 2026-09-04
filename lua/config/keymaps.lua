-- Keymaps that don't belong to a specific plugin.
-- Plugin-owned keymaps live next to their plugin in lua/plugins/*.lua.
local map = vim.keymap.set

-- The cheatsheet ------------------------------------------------------------
map("n", "<leader>?", function() require("config.cheatsheet").open() end,
  { desc = "Cheatsheet" })

-- The full web guide
map("n", "<leader>gu", function()
  vim.ui.open("https://claude.ai/code/artifact/fa81e147-7724-4e98-9a71-0a9f36c71547")
end, { desc = "Open the web guide" })

-- Themes. <leader>ut flips light/dark within the current family; <leader>uT
-- picks any of them with a live preview. Both persist across restarts.
-- See lua/config/theme.lua for why the two mechanisms differ.
map("n", "<leader>ut", function() require("config.theme").toggle_background() end,
  { desc = "Toggle light / dark" })
map("n", "<leader>uT", function()
  require("telescope.builtin").colorscheme({ enable_preview = true })
end, { desc = "Pick a colourscheme" })

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
vim.b.csv_header_on = false
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

-- Terminal mode --------------------------------------------------------------
map("t", "<C-/>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "<C-_>", "<C-\\><C-n>", { desc = "Exit terminal mode (tmux)" })

-- Move straight out of a terminal into an adjacent split, without having to
-- leave terminal mode first.
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
