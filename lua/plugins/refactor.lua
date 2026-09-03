-- Multi-cursor and project-wide replace: the two WebStorm reflexes with no
-- Neovim equivalent out of the box.
return {

  -- Multi-cursor -------------------------------------------------------------
  -- Keys are picked around what is already taken: <A-j>/<A-k> move lines and
  -- <C-Up>/<C-Down> resize windows, so neither is available here.
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    keys = {
      { "<C-n>", mode = { "n", "x" }, desc = "Cursor at next match" },
      { "<C-p>", mode = { "n", "x" }, desc = "Skip this match" },
      { "<leader>ma", mode = { "n", "x" }, desc = "Cursor on every match" },
      { "<leader>mj", desc = "Add cursor below" },
      { "<leader>mk", desc = "Add cursor above" },
      { "<C-LeftMouse>", mode = "n", desc = "Add cursor at click" },
    },
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local map = vim.keymap.set

      -- Grow the cursor set by matching the word or selection.
      map({ "n", "x" }, "<C-n>", function() mc.matchAddCursor(1) end,
        { desc = "Cursor at next match" })
      map({ "n", "x" }, "<C-p>", function() mc.matchSkipCursor(1) end,
        { desc = "Skip this match" })
      map({ "n", "x" }, "<leader>ma", mc.matchAllAddCursors,
        { desc = "Cursor on every match" })

      -- Grow it vertically.
      map("n", "<leader>mj", function() mc.lineAddCursor(1) end, { desc = "Add cursor below" })
      map("n", "<leader>mk", function() mc.lineAddCursor(-1) end, { desc = "Add cursor above" })

      map("n", "<C-LeftMouse>", mc.handleMouse, { desc = "Add cursor at click" })
      map("n", "<C-LeftDrag>", mc.handleMouseDrag, { desc = "Drag cursors" })

      -- Keys that only exist while extra cursors do.
      mc.addKeymapLayer(function(layer_set)
        layer_set({ "n", "x" }, "<left>", mc.prevCursor)
        layer_set({ "n", "x" }, "<right>", mc.nextCursor)
        layer_set({ "n", "x" }, "<leader>mx", mc.deleteCursor)
        layer_set("n", "<esc>", function()
          if mc.hasCursors() then mc.clearCursors() end
        end)
      end)
      -- The plugin sets its own highlights on ColorScheme and they read
      -- correctly against tokyonight, so nothing is overridden here.
    end,
  },

  -- Search and replace across the project ------------------------------------
  {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar", "GrugFarWithin" },
    keys = {
      {
        "<leader>sr",
        function() require("grug-far").open() end,
        desc = "Search & replace (project)",
      },
      {
        "<leader>sr",
        mode = "v",
        function() require("grug-far").with_visual_selection() end,
        desc = "Search & replace (selection)",
      },
      {
        "<leader>sw",
        function()
          require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
        end,
        desc = "Search & replace word under cursor",
      },
      {
        "<leader>sf",
        function()
          require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
        end,
        desc = "Search & replace (this file)",
      },
    },
    opts = {
      -- Same exclusions Telescope uses, so a replace can never rewrite build
      -- output or a dependency.
      engines = {
        ripgrep = {
          extraArgs = "--glob=!node_modules/** --glob=!dist/** --glob=!.angular/** "
            .. "--glob=!coverage/** --glob=!.terraform/** --glob=!*.lock "
            .. "--glob=!yarn.lock --glob=!package-lock.json",
        },
      },
      windowCreationCommand = "botright vsplit",
      keymaps = {
        replace = { n = "<localleader>r" },
        qflist = { n = "<localleader>q" },
        syncLocations = { n = "<localleader>s" },
        close = { n = "q" },
      },
    },
  },
}
