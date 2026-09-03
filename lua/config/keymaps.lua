-- Keymaps that don't belong to a specific plugin.
-- Plugin-owned keymaps live next to their plugin in lua/plugins/*.lua.
local map = vim.keymap.set

-- The cheatsheet ------------------------------------------------------------
map("n", "<leader>?", function() require("config.cheatsheet").open() end,
  { desc = "Cheatsheet" })

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

-- Terminal mode: get back to normal mode -------------------------------------
map("t", "<C-/>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "<C-_>", "<C-\\><C-n>", { desc = "Exit terminal mode (tmux)" })
