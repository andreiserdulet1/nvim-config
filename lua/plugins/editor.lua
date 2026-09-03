-- Finding things, moving around, and the file tree.
return {

  -- Telescope: the fuzzy finder everything routes through -------------------
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-ui-select.nvim",
    },
    keys = {
      { "<leader><space>", "<cmd>Telescope find_files<cr>", desc = "Find file" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep project" },
      { "<leader>fw", "<cmd>Telescope grep_string<cr>", desc = "Grep word under cursor" },
      { "<leader>fb", "<cmd>Telescope buffers sort_mru=true<cr>", desc = "Buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Symbols (file)" },
      { "<leader>fS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "Symbols (project)" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
      { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
      { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>fc", "<cmd>Telescope resume<cr>", desc = "Resume last search" },
      { "<leader>fp", function() require("config.projects").pick() end, desc = "Switch project" },
      { "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Git commits" },
    },
    opts = function()
      local actions = require("telescope.actions")
      return {
        defaults = {
          prompt_prefix = "   ",
          selection_caret = " ",
          path_display = { "truncate" },
          sorting_strategy = "ascending",
          layout_config = {
            horizontal = { prompt_position = "top", preview_width = 0.55 },
            width = 0.9,
            height = 0.85,
          },
          -- Never search build output or dependencies.
          file_ignore_patterns = {
            "node_modules", "%.git/", "dist/", "%.angular/", "coverage/",
            "%.terraform/", "target/", "%.lock", "yarn%.lock", "package%-lock%.json",
          },
          mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
              ["<Esc>"] = actions.close,   -- one Esc closes, no normal mode detour
            },
          },
        },
        pickers = {
          find_files = { hidden = true },
          buffers = { mappings = { i = { ["<C-d>"] = actions.delete_buffer } } },
        },
        extensions = {
          ["ui-select"] = { require("telescope.themes").get_dropdown() },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
    end,
  },

  -- File tree ---------------------------------------------------------------
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "File tree" },
      { "<leader>fe", "<cmd>Neotree reveal<cr>", desc = "Reveal file in tree" },
    },
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,   -- react to git checkouts / yarn install
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_by_name = { "node_modules", ".angular", ".terraform", "dist" },
        },
      },
      window = {
        width = 34,
        mappings = {
          ["<space>"] = "none",   -- keep <space> as leader inside the tree
          ["l"] = "open",
          ["h"] = "close_node",
        },
      },
      default_component_configs = {
        git_status = {
          symbols = {
            added = "", modified = "", deleted = "✖", renamed = "󰁕",
            untracked = "", ignored = "", unstaged = "󰄱", staged = "", conflict = "",
          },
        },
      },
    },
  },

  -- Renaming a file should fix the imports ----------------------------------
  -- vtsls has updateImportsOnFileMove enabled, but it only acts when the
  -- editor *tells* it a file moved. Without this, renaming a component in the
  -- tree leaves every importing file broken until the next compile.
  {
    "antosha417/nvim-lsp-file-operations",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-neo-tree/neo-tree.nvim" },
    event = "LspAttach",
    opts = {},
  },

  -- Session per project ------------------------------------------------------
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore this project's session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore the last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't save this session" },
    },
  },

  -- which-key: press <leader> and wait to see what's available ---------------
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = 400,
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>g", group = "git" },
        { "<leader>o", group = "component" },
        { "<leader>n", group = "run / test" },
        { "<leader>ng", group = "angular cli" },
        { "<leader>d", group = "debug" },
        { "<leader>gh", group = "hunk" },
        { "<leader>a", group = "ai (claude)" },
        { "<leader>t", group = "terminal" },
        { "<leader>x", group = "diagnostics" },
        { "<leader>u", group = "toggle" },
        { "<leader>m", group = "multi-cursor" },
        { "<leader>s", group = "search / replace" },
        { "<leader>p", group = "pull requests" },
        { "<leader>A", group = "github actions" },
        { "<leader>q", group = "session / quit" },
        { "<leader>w", group = "window" },
      },
    },
    keys = {
      { "<leader>fK", function() require("which-key").show({ global = true }) end, desc = "All keymaps" },
    },
  },

  -- Flash: jump to any visible word with `s` + two characters ---------------
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash treesitter" },
    },
  },

  -- Trouble: a proper list for diagnostics, references, quickfix ------------
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { focus = true },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnostics (file)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (project)" },
      { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols outline" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
    },
  },

  -- TODO / FIXME highlighting and a searchable list -------------------------
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
    keys = {
      { "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "TODO list" },
      { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Find TODOs" },
    },
  },

  -- Small, sharp editing helpers -------------------------------------------
  {
    "echasnovski/mini.nvim",
    event = "VeryLazy",
    config = function()
      require("mini.pairs").setup()      -- auto-close brackets and quotes
      require("mini.surround").setup()   -- gsa/gsd/gsr to add/delete/replace surroundings
      require("mini.comment").setup()    -- gcc to comment a line, gc in visual mode
      require("mini.ai").setup()         -- better text objects: cif, daf, ci(, etc.
    end,
  },

  -- Close and rename HTML/Angular tag pairs as you type ---------------------
  -- mini.pairs handles brackets and quotes; this handles <div> -> </div>.
  -- The htmlangular alias matters: Neovim gives *.component.html that
  -- filetype, and autotag keys off filetype, so without it this would do
  -- nothing in exactly the files that need it.
  {
    "windwp/nvim-ts-autotag",
    ft = { "html", "htmlangular", "xml", "javascript", "typescript",
           "javascriptreact", "typescriptreact", "vue", "markdown" },
    opts = {
      opts = { enable_close = true, enable_rename = true, enable_close_on_slash = false },
      aliases = { htmlangular = "html" },
    },
  },

  -- Treesitter: accurate syntax highlighting ------------------------------
  -- nvim-treesitter's `main` branch (the current default) dropped the old
  -- setup({ ensure_installed = ... }) API. Parsers are installed explicitly
  -- and highlighting is started per buffer.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup()

      -- Angular component templates use the `angular` parser.
      vim.treesitter.language.register("angular", "htmlangular")

      local parsers = {
        -- Angular / TypeScript
        "typescript", "tsx", "javascript", "angular", "html", "css", "scss",
        -- Infrastructure
        "terraform", "hcl", "yaml", "json", "dockerfile", "bash", "groovy",
        -- Editor / docs
        "lua", "vim", "vimdoc", "markdown", "markdown_inline", "regex",
        "gitcommit", "diff", "query",
      }

      local installed = require("nvim-treesitter.config").get_installed("parsers")
      local missing = vim.tbl_filter(function(p)
        return not vim.tbl_contains(installed, p)
      end, parsers)
      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end

      -- Start highlighting (and treesitter indentation) for any filetype that
      -- has a parser available.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          local ft = vim.bo[ev.buf].filetype
          if ft == "" then return end
          local lang = vim.treesitter.language.get_lang(ft)
          if not lang then return end
          if not pcall(vim.treesitter.language.add, lang) then return end
          pcall(vim.treesitter.start, ev.buf, lang)
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
