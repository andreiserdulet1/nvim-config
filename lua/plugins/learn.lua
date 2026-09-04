-- Getting comfortable: an undo safety net, and two optional teaching aids.
return {

  -- Undo history you can see -------------------------------------------------
  -- `undofile` is on, so history already survives restarts. This makes it
  -- visible and navigable, including branches -- the reassurance that matters
  -- when you are new and have just mangled a file.
  {
    "mbbill/undotree",
    cmd = { "UndotreeToggle", "UndotreeShow" },
    keys = {
      { "<leader>uu", "<cmd>UndotreeToggle<cr>", desc = "Toggle undo tree" },
    },
    init = function()
      vim.g.undotree_WindowLayout = 2
      vim.g.undotree_SplitWidth = 34
      vim.g.undotree_SetFocusWhenToggle = 1
    end,
  },

  -- Motion hints -------------------------------------------------------------
  -- Faint markers showing which motion reaches where. Genuinely useful for a
  -- week or two and visual noise afterwards, so it starts off.
  {
    "tris203/precognition.nvim",
    event = "VeryLazy",
    opts = { startVisible = false },
    keys = {
      { "<leader>up", function() require("precognition").toggle() end, desc = "Toggle motion hints" },
    },
  },

  -- Habit nagging ------------------------------------------------------------
  -- Warns when you hold hjkl or reach for the arrows, and names the motion you
  -- should have used. On by default; <leader>uH turns it off.
  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    event = "VeryLazy",
    opts = {
      -- Hardtime disables the mouse by default, which would silently break the
      -- <C-LeftMouse> multi-cursor keymap in plugins/refactor.lua. Keep it on.
      disable_mouse = false,
      max_count = 4,
      restriction_mode = "hint",   -- tell me, don't block the keypress
      -- Restricting keys inside another plugin's interface is the fastest way
      -- to end up uninstalling this, so stay out of them entirely.
      disabled_filetypes = {
        "neo-tree", "trouble", "toggleterm", "lazy", "mason", "help", "qf",
        "checkhealth", "undotree", "diff", "netrw", "oil", "octo", "grug-far",
        "snacks_dashboard", "cheatsheet", "dap-repl", "dapui_scopes",
        "dapui_breakpoints", "dapui_stacks", "dapui_watches", "dapui_console",
        "DiffviewFiles", "DiffviewFileHistory", "csv", "TelescopePrompt",
      },
    },
    keys = {
      {
        "<leader>uH",
        function()
          local h = require("hardtime")
          -- <leader>uh is already the CSV header toggle, hence the capital.
          if h.is_plugin_enabled then
            h.toggle()
          else
            vim.cmd("Hardtime toggle")
          end
          vim.notify("Hardtime toggled")
        end,
        desc = "Toggle hardtime nagging",
      },
    },
  },
}
