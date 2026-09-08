-- Colours, statusline, buffer tabs, and the start screen.
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
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = {
          { "diagnostics" },
          { "filename", path = 1 },  -- relative path, so you know which module
        },
        lualine_x = {
          -- Show which LSP servers are attached to this buffer.
          {
            function()
              local names = {}
              for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
                table.insert(names, client.name)
              end
              return table.concat(names, " ")
            end,
            icon = " ",
            color = { fg = "#7aa2f7" },
          },
          { "diff" },
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
        -- No neo-tree offset: bufferline offsets only reserve space on the LEFT
        -- edge, and the tree now opens on the right. Leaving it in would indent
        -- the tab bar on the side the tree is not on.
        diagnostics_indicator = function(_, _, diag)
          local s = {}
          if diag.error then table.insert(s, " " .. diag.error) end
          if diag.warning then table.insert(s, " " .. diag.warning) end
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
    opts = {
      bigfile = { enabled = true },      -- disable heavy features on huge files
      notifier = { enabled = true, timeout = 3000 },
      quickfile = { enabled = true },
      indent = { enabled = true, scope = { enabled = false } },
      input = { enabled = true },
      -- ui_select only -- this does NOT replace Telescope, which still owns
      -- every <leader>f key. It exists so vim.ui.select (config/actions.lua,
      -- scripts.lua, angular.lua, projects.lua, jira.lua) stops depending on
      -- telescope-ui-select, unmaintained since December 2023.
      picker = { enabled = true, ui_select = true },
      dashboard = {
        enabled = true,
        preset = {
          header = [[
      ███╗   ██╗██╗   ██╗██╗███╗   ███╗
      ████╗  ██║██║   ██║██║████╗ ████║
      ██╔██╗ ██║██║   ██║██║██╔████╔██║
      ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
      ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
      ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
                  angular · terraform]],
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":Telescope find_files" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Grep Text", action = ":Telescope live_grep" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":Telescope oldfiles" },
            { icon = " ", key = "p", desc = "Projects", action = ":lua require('config.projects').pick()" },
            { icon = " ", key = "?", desc = "Cheatsheet", action = ":lua require('config.cheatsheet').open()" },
            { icon = " ", key = "j", desc = "Jira sprint", action = ":lua require('config.jira').sprint()" },
            { icon = "󰒲 ", key = "l", desc = "Plugins", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
  },
}
