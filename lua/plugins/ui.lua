-- Colours, statusline, buffer tabs, and the start screen.
return {

  -- Colorscheme ------------------------------------------------------------
  -- These are the exact tokens from the web guide, mapped onto Neovim. The
  -- guide's dark palette was derived from tokyonight in the first place, so
  -- dark is a close cousin of stock storm; the light palette is custom and has
  -- no stock equivalent, which is why both are spelled out here.
  --
  -- Layering follows the page: the editor body is the page ground (bg), and
  -- floats, popups and the statusline sit on the raised surface.
  {
    "folke/tokyonight.nvim",
    priority = 1000,   -- load before everything else so there's no flash
    opts = {
      style = "night",
      light_style = "day",
      styles = {
        comments = { italic = true },
        keywords = { italic = false },
        floats = "normal",
        sidebars = "normal",
      },
      on_colors = function(c)
        if vim.o.background == "light" then
          c.bg            = "#e9ebf2"   -- --bg        page ground
          c.bg_dark       = "#dde1ec"   -- --rule-soft
          c.bg_float      = "#ffffff"   -- --surface
          c.bg_popup      = "#ffffff"
          c.bg_sidebar    = "#f2f4f9"   -- --surface-2
          c.bg_statusline = "#ffffff"
          c.bg_highlight  = "#dce3f4"   -- --accent-lo
          c.bg_visual     = "#ccd1e0"   -- --rule
          c.bg_search     = "#dce3f4"
          c.fg            = "#1a1b26"   -- --ink
          c.fg_dark       = "#3b3f52"   -- --ink-soft
          c.fg_sidebar    = "#3b3f52"
          c.fg_float      = "#1a1b26"
          c.fg_gutter     = "#ccd1e0"
          c.comment       = "#5f6683"   -- --muted
          c.border        = "#ccd1e0"   -- --rule
          c.border_highlight = "#34548a"
          c.blue          = "#34548a"   -- --accent
          c.blue1         = "#34548a"
          c.cyan          = "#33635c"
          c.teal          = "#33635c"
          c.purple        = "#6a4fa3"   -- --violet
          c.magenta       = "#6a4fa3"
          c.green         = "#4a7a2e"   -- --green
          c.yellow        = "#8a6414"   -- --amber
          c.orange        = "#8a6414"
          c.red           = "#a1425a"   -- --red
          c.error         = "#a1425a"
          c.warning       = "#8a6414"
          c.info          = "#34548a"
          c.hint          = "#33635c"
        else
          c.bg            = "#15161e"   -- --bg        page ground
          c.bg_dark       = "#101017"
          c.bg_float      = "#1a1b26"   -- --surface
          c.bg_popup      = "#1a1b26"
          c.bg_sidebar    = "#1a1b26"
          c.bg_statusline = "#1a1b26"
          c.bg_highlight  = "#1f2130"   -- --surface-2
          c.bg_visual     = "#2c3048"   -- --rule
          c.bg_search     = "#1e2740"   -- --accent-lo
          c.fg            = "#c8d3f5"   -- --ink
          c.fg_dark       = "#a9b3d9"   -- --ink-soft
          c.fg_sidebar    = "#a9b3d9"
          c.fg_float      = "#c8d3f5"
          c.fg_gutter     = "#2c3048"
          c.comment       = "#787f99"   -- --muted
          c.border        = "#2c3048"   -- --rule
          c.border_highlight = "#7aa2f7"
          c.blue          = "#7aa2f7"   -- --accent
          c.blue1         = "#7aa2f7"
          c.purple        = "#bb9af7"   -- --violet
          c.magenta       = "#bb9af7"
          c.green         = "#9ece6a"   -- --green
          c.yellow        = "#e0af68"   -- --amber
          c.orange        = "#e0af68"
          c.red           = "#f7768e"   -- --red
          c.error         = "#f7768e"
          c.warning       = "#e0af68"
          c.info          = "#7aa2f7"
        end
      end,
      on_highlights = function(hl, c)
        -- The guide's hairline rules, applied to the editor's own dividers.
        hl.WinSeparator  = { fg = c.border, bold = false }
        hl.FloatBorder   = { fg = c.border, bg = c.bg_float }
        hl.NormalFloat   = { fg = c.fg_float, bg = c.bg_float }
        hl.CursorLine    = { bg = c.bg_highlight }
        hl.CursorLineNr  = { fg = c.blue, bold = true }
        hl.LineNr        = { fg = c.fg_gutter }
        hl.Comment       = { fg = c.comment, italic = true }
        -- Telescope, to match the guide's card-on-ground layering.
        hl.TelescopeNormal       = { fg = c.fg_float, bg = c.bg_float }
        hl.TelescopeBorder       = { fg = c.border, bg = c.bg_float }
        hl.TelescopePromptNormal = { bg = c.bg_highlight }
        hl.TelescopePromptBorder = { fg = c.bg_highlight, bg = c.bg_highlight }
        hl.TelescopePromptTitle  = { fg = c.bg, bg = c.blue, bold = true }
        hl.TelescopeResultsTitle = { fg = c.bg_float, bg = c.bg_float }
        hl.TelescopePreviewTitle = { fg = c.bg, bg = c.green, bold = true }
        hl.TelescopeSelection    = { bg = c.bg_visual, bold = true }
      end,
    },
    config = function(_, opts)
      -- Default to the dark palette; <leader>ut swaps to light.
      if vim.g.nvim_theme_background then
        vim.o.background = vim.g.nvim_theme_background
      else
        vim.o.background = "dark"
      end
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Statusline -------------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "tokyonight",
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
        -- Keep the file tree in its own column instead of overlapping tabs.
        offsets = {
          { filetype = "neo-tree", text = "Explorer", highlight = "Directory", separator = true },
        },
        -- Angular projects are full of same-named files (component.ts in every
        -- folder), so show enough path to tell them apart.
        name_formatter = function(buf)
          return vim.fn.fnamemodify(buf.name, ":t")
        end,
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
