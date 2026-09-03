-- Claude and terminals.
return {

  -- claudecode.nvim connects the `claude` CLI to this Neovim session.
  -- Selections become real file references, and Claude's edits arrive as a
  -- native Neovim diff you accept or reject rather than as pasted text.
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSend", "ClaudeCodeAdd",
      "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny", "ClaudeCodeSelectModel",
    },
    opts = {
      terminal = {
        split_side = "right",
        split_width_percentage = 0.38,
        provider = "snacks",
      },
      diff_opts = {
        auto_close_on_accept = true,
        vertical_split = true,
      },
    },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add this file to context" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file from tree",
        ft = { "neo-tree" },
      },
      -- Reviewing what Claude proposes
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude's edit" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Reject Claude's edit" },
    },
  },

  -- Plain terminals: a floating shell, and one pinned to the project root.
  {
    "akinsho/toggleterm.nvim",
    cmd = { "ToggleTerm", "TermExec" },
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
      { "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", desc = "Floating terminal" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "Horizontal terminal" },
      {
        "<leader>tn",
        function()
          -- A terminal that always opens at the project root, so `yarn start`
          -- or `make plan` runs from the right directory.
          local root = vim.fs.root(0, { ".git", "package.json", "terragrunt.hcl" }) or vim.uv.cwd()
          require("toggleterm.terminal").Terminal
            :new({ dir = root, direction = "float", hidden = true })
            :toggle()
        end,
        desc = "Terminal at project root",
      },
      {
        "<leader>tc",
        function()
          -- Fallback plain `claude` CLI in a float, independent of the
          -- claudecode.nvim integration above.
          require("toggleterm.terminal").Terminal
            :new({ cmd = "claude", direction = "float", hidden = true, close_on_exit = false })
            :toggle()
        end,
        desc = "Claude (plain terminal)",
      },
    },
    opts = {
      size = 15,
      open_mapping = nil,
      shade_terminals = false,
      start_in_insert = true,
      float_opts = { border = "rounded", width = function() return math.floor(vim.o.columns * 0.9) end,
                     height = function() return math.floor(vim.o.lines * 0.85) end },
    },
  },
}
