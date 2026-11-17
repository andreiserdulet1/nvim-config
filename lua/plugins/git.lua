-- Git: lazygit for anything involved, gitsigns for hunks, diffview for review
-- and for merge conflicts.
--
-- git-conflict.nvim used to handle in-buffer conflict resolution. It was
-- dropped: upstream went quiet in December 2024, and its disable_diagnostics
-- path calls vim.diagnostic.disable(), which Neovim 0.12 removed, so it needed
-- a hand-rolled workaround here to be usable at all. Diffview's 3-pane merge
-- view (<leader>gx) does the same job with the same keys.
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

      -- <C-h/j/k/l> step between splits from terminal mode (config/keymaps.lua),
      -- which means they never reach a program running in one. lazygit binds
      -- <C-j>/<C-k> to move a commit down/up in an interactive rebase and <C-l>
      -- to the log menu, so inside this float they were silently dead. They are
      -- worth more to lazygit than to window navigation here: you leave the
      -- float with `q`, not by stepping sideways out of it. Buffer-local maps
      -- win over global ones, so this scopes the exception to lazygit alone.
      vim.api.nvim_create_autocmd("TermOpen", {
        group = vim.api.nvim_create_augroup("lazygit_passthrough", { clear = true }),
        callback = function(ev)
          -- lazygit.nvim starts the job with jobstart({ term = true }), so the
          -- buffer is named term://<cwd>//<pid>:<path to lazygit>.
          if not vim.api.nvim_buf_get_name(ev.buf):match("lazygit") then
            return
          end
          for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
            vim.keymap.set("t", key, key, { buffer = ev.buf, desc = "Pass through to lazygit" })
          end
        end,
      })
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
        -- Blocks rather than Nerd glyphs, to match the "▎" above: the gutter
        -- stays legible even in a terminal without a patched font.
        delete = { text = "▁" },
        topdelete = { text = "▔" },
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
        -- stage_hunk toggles: on an unstaged hunk it stages, on a staged sign
        -- it unstages. That replaces the old undo_stage_hunk, which gitsigns
        -- now marks @deprecated.
        map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage / unstage hunk")
        map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset hunk")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview hunk")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>gB", function() gs.blame() end, "Blame file")
        -- <leader>ug, not <leader>ub: buffer-local maps beat global ones, and
        -- <leader>ub is the background-painting picker in config/keymaps.lua.
        -- Mapping it here shadowed that picker in every file in a git repo.
        map("n", "<leader>ug", gs.toggle_current_line_blame, "Toggle inline blame")
        -- ih is a text object: `dih` deletes the hunk under the cursor.
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
      end,
    },
  },

  -- GitHub pull requests, in the editor --------------------------------------
  -- Drives the `gh` CLI you're already authenticated with, so reviewing a
  -- teammate's branch doesn't mean a browser round-trip. commissions-ui is at
  -- PR #152 and aws-infrastructure-billing at #410, so this gets real use.
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      picker = "telescope",
      use_local_fs = false,
      enable_builtin = true,
      suppress_missing_scope = { projects_v2 = true },
    },
    keys = {
      { "<leader>pl", "<cmd>Octo pr list<cr>", desc = "PRs in this repo" },
      { "<leader>pp", "<cmd>Octo pr<cr>", desc = "PR for this branch" },
      { "<leader>pr", "<cmd>Octo review start<cr>", desc = "Start a review" },
      { "<leader>pR", "<cmd>Octo review submit<cr>", desc = "Submit the review" },
      { "<leader>pi", "<cmd>Octo issue list<cr>", desc = "Issues" },
      { "<leader>ps", "<cmd>Octo search<cr>", desc = "Search PRs and issues" },
    },
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
      view = {
        merge_tool = {
          -- OURS | the file you are producing | THEIRS, side by side: the same
          -- arrangement WebStorm's merge dialog uses, and the one the mouse
          -- support in config/conflicts.lua is written for -- what you click is
          -- always in the middle, and the side you took it from is beside it.
          -- diff3_mixed put the result underneath, which reads as a summary of
          -- the two panes above rather than as the thing you are editing.
          layout = "diff3_horizontal",
        },
      },
      hooks = {
        -- Make the middle pane clickable. The hook fires per window, and
        -- attach() decides whether this is the pane it means.
        diff_buf_win_enter = function(bufnr, winid, ctx)
          require("config.conflicts").attach(bufnr, winid, ctx)
        end,
        view_closed = function(view)
          require("config.conflicts").forget(view)
        end,
      },
    },
  },
}
