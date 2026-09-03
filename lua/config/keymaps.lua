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

-- Light / dark, matching the two palettes in the web guide. The choice is
-- written to a small file so it survives restarting Neovim.
local theme_file = vim.fn.stdpath("data") .. "/theme-background"
map("n", "<leader>ut", function()
  local next_bg = vim.o.background == "dark" and "light" or "dark"
  vim.o.background = next_bg
  vim.cmd.colorscheme("tokyonight")
  pcall(vim.fn.writefile, { next_bg }, theme_file)
  vim.notify("Theme: " .. next_bg)
end, { desc = "Toggle light/dark theme" })

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

-- Run and test this project --------------------------------------------------
local scripts = function(fn, ...)
  local args = { ... }
  return function() require("config.scripts")[fn](unpack(args)) end
end
map("n", "<leader>nr", scripts("pick"), { desc = "Pick a package.json script" })
map("n", "<leader>nt", scripts("test_file"), { desc = "Test this component" })
map("n", "<leader>na", scripts("test_all", false), { desc = "Test everything (once)" })
map("n", "<leader>nw", scripts("test_all", true), { desc = "Test everything (watch)" })
map("n", "<leader>ns", scripts("run", "start"), { desc = "Start the dev server" })
map("n", "<leader>nl", scripts("run", "lint"), { desc = "Lint" })

-- Saving / quitting ---------------------------------------------------------
map({ "n", "i", "v" }, "<C-s>", "<cmd>write<cr><esc>", { desc = "Save file" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- Clear search highlight on Escape ------------------------------------------
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

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
