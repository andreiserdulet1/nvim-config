-- Colours, statusline, buffer tabs, and the start screen.
local icons = require("config.icons")

return {

  -- Colourschemes live in colors/ and lua/scheme/, not here: they ship with
  -- this repo rather than coming from a plugin, so there is nothing for
  -- lazy.nvim to install and no eager plugin needed to avoid a flash of the
  -- wrong palette. init.lua applies the saved one directly.

  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Statusline -------------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",   -- follow whatever colorscheme is active
        globalstatus = true,
        section_separators = {
          left = icons.separator.section_left, right = icons.separator.section_right,
        },
        component_separators = {
          left = icons.separator.component_left, right = icons.separator.component_right,
        },
      },
      sections = {
        lualine_a = { "mode" },
        -- on_click turns each component that names a thing into a way of
        -- opening it: the branch is where lazygit lives, the diagnostic count
        -- is the Trouble list, the diff stat is the diffview. Same destinations
        -- as <leader>gg, <leader>xx and <leader>gd, reachable without them.
        lualine_b = {
          -- Left: lazygit. Right: the JetBrains-style git menu.
          {
            "branch",
            on_click = function(_, button)
              if button == "r" then require("config.vcs").menu() else vim.cmd("LazyGit") end
            end,
          },
        },
        lualine_c = {
          {
            "diagnostics",
            on_click = function() vim.cmd("Trouble diagnostics toggle filter.buf=0") end,
          },
          -- Relative path, so you know which module. Click it to copy a path,
          -- a GitHub link or a snippet.
          { "filename", path = 1, on_click = function() require("config.copy").menu() end },
        },
        lualine_x = {
          -- Buttons. Everything here is clickable: left click does the obvious
          -- thing, right click opens the options. Same actions as the keys
          -- shown in the palette (☰ / <C-p>).
          {
            function() return require("config.services").status() end,
            color = function()
              local hl = require("config.services").status_hl()
              return hl and { fg = Snacks.util.color(hl) } or nil
            end,
            on_click = function(_, button)
              local services = require("config.services")
              if button == "r" and next(services.running) then services.stop() else services.menu() end
            end,
          },
          {
            function() return require("config.claude").status() end,
            color = function()
              return require("config.claude").is_running() and { fg = Snacks.util.color("Function") } or nil
            end,
            on_click = function(_, button)
              if button == "r" then require("config.claude").layout_menu() else require("config.claude").toggle() end
            end,
          },
          {
            function() return require("config.actions").ci_status() end,
            on_click = function() require("config.actions").list() end,
          },
          {
            function() return "☰" end,
            on_click = function() require("config.palette").open() end,
          },
          -- Show which LSP servers are attached to this buffer.
          {
            function()
              local names = {}
              for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
                table.insert(names, client.name)
              end
              return table.concat(names, " ")
            end,
            on_click = function() vim.cmd("checkhealth vim.lsp") end,
            icon = icons.lsp,
            -- Was a hard-coded #7aa2f7 -- tokyonight's blue, which outlived that
            -- theme's removal and sat as a stray cool note in four warm
            -- statuslines. Linked instead, so it follows whatever is active.
            color = "Function",
          },
          { "diff", on_click = function() vim.cmd("DiffviewOpen") end },
          { "filetype" },
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
    config = function(_, opts)
      -- lualine's "auto" theme is unreadable against these palettes: measured
      -- 3.34:1 on the mode block and 3.19:1 beside it against graphite, both
      -- under the 4.5:1 floor. Build the table from the active scheme's own
      -- palette instead, and fall back to "auto" for anything else.
      local function resolve()
        local ok, m = pcall(require, "scheme.lualine")
        -- get() returns a plain table; a lazy metatable version produced an
        -- empty statusline because LuaJIT has no __pairs.
        if ok then
          local theme = m.get(vim.g.colors_name)
          if theme then return theme end
        end
        return "auto"
      end

      opts.options.theme = resolve()
      require("lualine").setup(opts)

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("scheme_lualine", { clear = true }),
        callback = function()
          opts.options.theme = resolve()
          require("lualine").setup(opts)
        end,
      })
    end,
  },

  -- Buffer tabs along the top ----------------------------------------------
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      -- Snacks.bufdelete closes the buffer but leaves the window alone, so a
      -- split survives instead of collapsing the way :bdelete makes it.
      { "<leader>bd", function() require("snacks").bufdelete() end, desc = "Close buffer" },
      { "<leader>bD", function() require("snacks").bufdelete({ force = true }) end,
        desc = "Close buffer (discard changes)" },
      { "<leader>bo", function() require("snacks").bufdelete.other() end, desc = "Close other buffers" },
      { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin buffer" },
    },
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        always_show_bufferline = true,
        show_buffer_close_icons = true,
        separator_style = "slant",
        -- Reveal the close button on the tab under the pointer. Needs
        -- mousemoveevent, set in config/options.lua.
        hover = { enabled = true, delay = 200, reveal = { "close" } },
        -- Every mouse route to closing a buffer goes through Snacks.bufdelete,
        -- for the same reason <leader>bd does: bufferline's default is
        -- `bdelete! %d`, which takes the split down with the buffer. The
        -- keyboard already did the right thing here and the mouse did not.
        close_command = function(n) require("snacks").bufdelete(n) end,
        -- Right-click is a menu (close, others, pin, copy path, GitHub, …);
        -- middle-click still closes in one go.
        right_mouse_command = function(n) require("config.menu").buffer(n) end,
        middle_mouse_command = function(n) require("snacks").bufdelete(n) end,
        -- No neo-tree offset: bufferline offsets only reserve space on the LEFT
        -- edge, and the tree now opens on the right. Leaving it in would indent
        -- the tab bar on the side the tree is not on.
        diagnostics_indicator = function(_, _, diag)
          local s = {}
          -- Same codicons as the diagnostic signs in options.lua, so the
          -- gutter and the tab bar agree about what an error looks like.
          if diag.error then table.insert(s, icons.diagnostic.error .. diag.error) end
          if diag.warning then table.insert(s, icons.diagnostic.warn .. diag.warning) end
          return table.concat(s, " ")
        end,
      },
    },
    config = function(_, opts)
      require("bufferline").setup(opts)
      -- <leader>1..9 jumps straight to that tab.
      for i = 1, 9 do
        vim.keymap.set("n", "<leader>" .. i, function()
          require("bufferline").go_to(i, true)
        end, { desc = "Go to buffer " .. i })
      end
    end,
  },

  -- Breadcrumbs in the winbar ------------------------------------------------
  -- Shows Class > method at the top of the window, which is the orientation
  -- you lose in a 400-line component. Safe with laststatus = 3.
  {
    "Bekaboo/dropbar.nvim",
    event = "BufReadPost",
    opts = {
      bar = {
        enable = function(buf, win, _)
          if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
            return false
          end
          -- A winbar is noise in the tree, in lists and in terminals.
          local ft = vim.bo[buf].filetype
          local skip = {
            ["neo-tree"] = true, ["trouble"] = true, ["toggleterm"] = true,
            ["dapui_scopes"] = true, ["dapui_breakpoints"] = true,
            ["dapui_stacks"] = true, ["dapui_watches"] = true, ["dapui_console"] = true,
            ["dap-repl"] = true, ["snacks_dashboard"] = true, ["cheatsheet"] = true,
            ["grug-far"] = true, ["octo"] = true, ["help"] = true, ["qf"] = true,
            ["DiffviewFiles"] = true, ["DiffviewFileHistory"] = true,
          }
          if skip[ft] or vim.bo[buf].buftype ~= "" then return false end
          -- Nor in a diff window. The merge view labels its own panes -- which
          -- side each one is, and which conflict you are on (config/conflicts)
          -- -- and a breadcrumb would just overwrite that with the file name
          -- you already know, three times over.
          if vim.wo[win].diff then return false end
          return true
        end,
      },
    },
    keys = {
      { "<leader>;", function() require("dropbar.api").pick() end, desc = "Pick from the breadcrumb" },
    },
  },

  -- Markdown, rendered in place ----------------------------------------------
  -- 474 markdown files across these repos, including prepayment-service/adrs
  -- and four docs/ trees.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      heading = { sign = false, width = "block", left_pad = 0, right_pad = 2 },
      code = { sign = false, width = "block", left_pad = 2, right_pad = 2 },
      -- Render everywhere except the line you're editing, so the raw syntax is
      -- there when you need to change it.
      anti_conceal = { enabled = true },
    },
    keys = {
      { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown rendering" },
    },
  },

  -- Start screen, big-file handling, pretty notifications -------------------
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    init = function()
      -- The dashboard already snaps the cursor to the nearest entry as it
      -- moves, so a click lands on one -- there was just no way to then run it
      -- without reaching for its letter. <cr> is mapped buffer-locally by the
      -- dashboard itself, so a double click can simply ask for it, and stays
      -- correct if the entries in `preset.keys` below ever change.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("dashboard_click", { clear = true }),
        pattern = "snacks_dashboard",
        callback = function(ev)
          vim.keymap.set("n", "<2-LeftMouse>", function()
            vim.api.nvim_feedkeys(vim.keycode("<CR>"), "m", false)
          end, { buffer = ev.buf, desc = "Run the entry under the pointer" })
        end,
      })
    end,
    opts = {
      bigfile = { enabled = true },      -- disable heavy features on huge files
      notifier = { enabled = true, timeout = 3000 },
      quickfile = { enabled = true },
      indent = { enabled = true, scope = { enabled = false } },
      words = { enabled = true },        -- highlight the symbol under the cursor, ]] / [[ to walk its references
      input = { enabled = true },
      -- The one picker: every <leader>f key (plugins/editor.lua), and every
      -- vim.ui.select in config/ (scripts, services, actions, jira, projects).
      picker = { enabled = true, ui_select = true },
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            { icon = "▶ ", key = "s", desc = "Start this project", action = ":lua require('config.services').start()" },
            { icon = "▶ ", key = "S", desc = "Start inside shell-ui", action = ":lua require('config.services').start_with_shell()" },
            { icon = "✦ ", key = "c", desc = "Continue Claude conversation", action = ":lua require('config.claude').continue()" },
            { icon = icons.dashboard.find, key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
            { icon = icons.dashboard.grep, key = "g", desc = "Grep Text", action = ":lua Snacks.picker.grep()" },
            { icon = icons.dashboard.recent, key = "r", desc = "Recent Files", action = ":lua Snacks.picker.recent({ filter = { cwd = true } })" },
            { icon = icons.dashboard.projects, key = "p", desc = "Projects", action = ":lua require('config.projects').pick()" },
            { icon = "☰ ", key = "k", desc = "All commands", action = ":lua require('config.palette').open()" },
            { icon = icons.dashboard.jira, key = "j", desc = "Jira sprint", action = ":lua require('config.jira').sprint()" },
            { icon = icons.dashboard.cheatsheet, key = "?", desc = "Cheatsheet", action = ":lua require('config.cheatsheet').open()" },
            { icon = icons.dashboard.plugins, key = "l", desc = "Plugins", action = ":Lazy" },
            { icon = icons.dashboard.quit, key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
  },
}
