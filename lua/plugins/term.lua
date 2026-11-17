-- Claude and terminals. Every terminal window gets a clickable bar to move or
-- hide it (config/layout.lua).
return {

  -- claudecode.nvim connects the `claude` CLI to this Neovim session.
  -- Selections become real file references, and Claude's edits arrive as a
  -- native Neovim diff you accept or reject rather than as pasted text.
  -- Positioning, conversations and the "ask about this" helpers are in
  -- config/claude.lua.
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSend", "ClaudeCodeAdd", "ClaudeCodeTreeAdd",
      "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny", "ClaudeCodeSelectModel",
    },
    opts = function()
      -- Open wherever Claude was last put (<leader>ap / the winbar buttons).
      local placement = require("config.claude").opts()
      return {
        terminal = vim.tbl_deep_extend("force", {
          split_side = "right",
          split_width_percentage = 0.38,
          provider = "snacks",
        }, placement),
        diff_opts = {
          auto_close_on_accept = true,
          vertical_split = true,
        },
      }
    end,
    keys = {
      { "<leader>ac", function() require("config.claude").toggle() end, desc = "Show / hide Claude" },
      { "<leader>af", function() require("config.claude").focus() end, desc = "Focus Claude" },
      { "<leader>aC", function() require("config.claude").continue() end, desc = "Continue last conversation" },
      { "<leader>ar", function() require("config.claude").resume() end, desc = "Resume a conversation" },
      { "<leader>an", function() require("config.claude").new() end, desc = "New conversation" },
      { "<leader>ap", function() require("config.claude").layout_menu() end, desc = "Move Claude's window" },
      { "<leader>a=", function() require("config.claude").resize(5) end, desc = "Grow Claude's window" },
      { "<leader>a-", function() require("config.claude").resize(-5) end, desc = "Shrink Claude's window" },
      { "<leader>aq", function() require("config.claude").ask() end, mode = { "n", "x" }, desc = "Ask about this" },
      { "<leader>ax", function() require("config.claude").fix() end, mode = { "n", "x" }, desc = "Fix diagnostics here" },
      { "<leader>ai", function() require("config.claude").explain() end, mode = { "n", "x" }, desc = "Explain this" },
      { "<leader>at", function() require("config.claude").spec() end, desc = "Write tests for this component" },
      { "<leader>aR", function() require("config.claude").review() end, desc = "Review uncommitted changes" },
      { "<leader>ae", function() require("config.services").send_to_claude() end, desc = "Send dev server output" },
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
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "Terminal at the bottom" },
      { "<leader>tv", "<cmd>ToggleTerm direction=vertical size=80<cr>", desc = "Terminal on the right" },
      { "<leader>tm", function() require("config.layout").cycle() end, desc = "Move this terminal" },
      {
        "<leader>tn",
        function()
          -- A terminal that always opens at the project root, so `yarn start`
          -- or `make plan` runs from the right directory.
          local terms = require("toggleterm.terminal")
          local root = vim.fs.root(0, { ".git", "package.json", "terragrunt.hcl" }) or vim.uv.cwd()
          -- One shell per project root, reused: pressing this again returns you
          -- to the shell you left rather than starting a fresh one beside it.
          local existing = terms.find(function(t)
            return t.project_shell and vim.fs.normalize(t.dir or "") == vim.fs.normalize(root)
          end)
          if existing then
            existing:toggle()
            return
          end
          terms.Terminal
            :new({
              dir = root,
              direction = "float",
              hidden = true,
              display_name = "shell @ " .. vim.fs.basename(root),
              project_shell = true,
            })
            :toggle()
        end,
        desc = "Terminal at project root",
      },
      -- Switching between terminals
      { "<leader>tl", "<cmd>TermSelect!<cr>", desc = "List / switch terminals" },
      { "<leader>t1", "<cmd>1ToggleTerm<cr>", desc = "Terminal 1" },
      { "<leader>t2", "<cmd>2ToggleTerm<cr>", desc = "Terminal 2" },
      { "<leader>t3", "<cmd>3ToggleTerm<cr>", desc = "Terminal 3" },
      {
        "<leader>tx",
        function()
          -- Close the terminal you're looking at, whether you're inside it or
          -- it's just the last one you opened.
          local terms = require("toggleterm.terminal")
          local current = terms.get(terms.get_focused_id(), true)
          if not current then
            -- Dev servers are stopped with <leader>nx, never by accident here.
            local all = vim.tbl_filter(function(t) return not t.service end, terms.get_all(true))
            current = all[#all]
          end
          if current then
            current:shutdown()
          else
            vim.notify("No terminal open")
          end
        end,
        desc = "Close this terminal",
      },
      {
        "<leader>tX",
        function()
          -- Dev servers are left alone: <leader>nx stops those.
          local all = vim.tbl_filter(function(t) return not t.service end,
            require("toggleterm.terminal").get_all(true))
          if #all == 0 then vim.notify("No terminals open") return end
          for _, t in ipairs(all) do t:shutdown() end
          vim.notify("Closed " .. #all .. " terminal(s)")
        end,
        desc = "Close all terminals (not dev servers)",
      },
    },
    opts = {
      size = function(term)
        if term.direction == "vertical" then return math.floor(vim.o.columns * 0.4) end
        return 15
      end,
      open_mapping = nil,
      shade_terminals = false,
      start_in_insert = true,
      float_opts = { border = "rounded", width = function() return math.floor(vim.o.columns * 0.9) end,
                     height = function() return math.floor(vim.o.lines * 0.85) end },
    },
  },
}
