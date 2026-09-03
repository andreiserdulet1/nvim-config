-- Git: lazygit for anything involved, gitsigns for hunks, diffview for review.
return {

  -- lazygit in a floating window. This is the "smart git command" -----------
  -- <leader>gg from any buffer opens lazygit rooted at that buffer's repo.
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit (repo)" },
      { "<leader>gf", "<cmd>LazyGitFilterCurrentFile<cr>", desc = "LazyGit (file history)" },
      { "<leader>gl", "<cmd>LazyGitFilter<cr>", desc = "LazyGit (commit log)" },
    },
    init = function()
      vim.g.lazygit_floating_window_scaling_factor = 0.95
      vim.g.lazygit_floating_window_border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
      vim.g.lazygit_use_neovim_remote = 0
    end,
  },

  -- Gutter signs, hunk staging, inline blame ---------------------------------
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      current_line_blame = false,
      current_line_blame_opts = { delay = 300, virt_text_pos = "eol" },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns
        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Previous hunk")
        map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage hunk")
        map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset hunk")
        map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo stage hunk")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview hunk")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>gB", function() gs.blame() end, "Blame file")
        map("n", "<leader>ub", gs.toggle_current_line_blame, "Toggle inline blame")
        -- ih is a text object: `dih` deletes the hunk under the cursor.
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
      end,
    },
  },

  -- In-buffer conflict resolution -------------------------------------------
  -- For a two-line conflict, opening a separate diff view is heavier than the
  -- job needs. This resolves conflicts in the file you are already looking at.
  --
  -- default_mappings is off on purpose: the plugin's defaults are co/ct/cb, and
  -- `ct` is a real operator-motion (ct) = "change up to the next paren"). Having
  -- that silently change meaning inside a conflicted buffer would be a trap.
  -- The keys below match diffview's merge-view keys instead, so conflicts use
  -- one set of keys wherever you meet them.
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = "BufReadPre",
    opts = {
      default_mappings = false,
      default_commands = true,
      -- Left off deliberately: the plugin's own implementation calls
      -- vim.diagnostic.disable(), which Neovim 0.12 removed, so enabling this
      -- throws on every conflicted buffer. Handled with the current API below.
      disable_diagnostics = false,
      highlights = {
        current = "DiffAdd",
        incoming = "DiffText",
        ancestor = "DiffChange",
      },
    },
    config = function(_, opts)
      require("git-conflict").setup(opts)

      vim.api.nvim_create_autocmd("User", {
        pattern = "GitConflictDetected",
        callback = function(ev)
          local buf = ev.buf or 0
          local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
          end
          map("<leader>co", "<cmd>GitConflictChooseOurs<cr>", "Conflict: take ours")
          map("<leader>ct", "<cmd>GitConflictChooseTheirs<cr>", "Conflict: take theirs")
          map("<leader>cb", "<cmd>GitConflictChooseBoth<cr>", "Conflict: take both")
          map("<leader>cn", "<cmd>GitConflictChooseNone<cr>", "Conflict: take neither")
          map("]x", "<cmd>GitConflictNextConflict<cr>", "Next conflict")
          map("[x", "<cmd>GitConflictPrevConflict<cr>", "Previous conflict")

          -- Relabel the <leader>c menu while a conflict is present, so which-key
          -- doesn't advertise "code" when these keys mean something else.
          pcall(function()
            require("which-key").add({ "<leader>c", group = "conflict", buffer = buf })
          end)

          -- A conflicted file isn't valid TypeScript, so its diagnostics are
          -- noise until the markers are gone.
          vim.diagnostic.enable(false, { bufnr = buf })

          vim.notify("Conflicts in this file — <leader>co / ct / cb, ]x to move",
            vim.log.levels.WARN)
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "GitConflictResolved",
        callback = function(ev)
          local buf = ev.buf or 0
          for _, lhs in ipairs({ "<leader>co", "<leader>ct", "<leader>cb", "<leader>cn", "]x", "[x" }) do
            pcall(vim.keymap.del, "n", lhs, { buffer = buf })
          end
          vim.diagnostic.enable(true, { bufnr = buf })
          pcall(function()
            require("which-key").add({ "<leader>c", group = "code", buffer = buf })
          end)
        end,
      })
    end,
  },

  -- Diffview: review a whole branch or PR inside Neovim ----------------------
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview (working tree)" },
      { "<leader>gm", "<cmd>DiffviewOpen origin/master...HEAD<cr>", desc = "Diff vs master" },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (diffview)" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close diffview" },
      {
        "<leader>gx",
        function()
          -- Open the three-pane merge view, but only when there is actually
          -- something to merge. Opening diffview on a clean repo just shows an
          -- empty working-tree diff and leaves you guessing.
          local files = require("config.conflicts").unmerged()
          if #files == 0 then
            vim.notify("No conflicts in this repo")
            return
          end
          vim.notify(#files .. " conflicted file(s)")
          vim.cmd("DiffviewOpen")
        end,
        desc = "Resolve conflicts (3-pane)",
      },
      {
        "<leader>gX",
        function() require("config.conflicts").to_quickfix() end,
        desc = "List conflicted files",
      },
    },
    opts = {
      enhanced_diff_hl = true,
      view = { merge_tool = { layout = "diff3_mixed" } },
    },
  },
}
