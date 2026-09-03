-- Colours, statusline, buffer tabs, and the start screen.
return {

  -- Colorscheme ------------------------------------------------------------
  {
    "folke/tokyonight.nvim",
    priority = 1000,   -- load before everything else so there's no flash
    opts = {
      style = "storm",
      styles = { comments = { italic = true }, keywords = { italic = false } },
    },
    config = function(_, opts)
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
      { "<leader>bd", "<cmd>bdelete<cr>", desc = "Close buffer" },
      { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Close other buffers" },
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
