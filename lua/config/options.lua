-- Editor behaviour. Everything here is plain Neovim, no plugins involved.
local opt = vim.opt

-- Appearance -----------------------------------------------------------------
opt.number = true            -- absolute line number on the cursor line
opt.relativenumber = true    -- relative elsewhere, so 5j / 12k are easy to judge
opt.signcolumn = "yes"       -- always reserve the gutter so text never jumps
opt.termguicolors = true     -- 24-bit colour (iTerm2 supports it)
opt.cursorline = true
opt.wrap = false
opt.scrolloff = 8            -- keep 8 lines of context above/below the cursor
opt.sidescrolloff = 8
opt.showmode = false         -- lualine already shows the mode
opt.laststatus = 3           -- one global statusline, not one per split
opt.pumheight = 12           -- cap completion popup height
opt.winborder = "rounded"    -- rounded borders for hover/float windows (0.11+)

-- Indentation ----------------------------------------------------------------
-- 2 spaces matches Angular/Prettier and Terraform conventions alike.
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- Search ---------------------------------------------------------------------
opt.ignorecase = true
opt.smartcase = true         -- ...unless the query contains a capital letter
opt.hlsearch = true
opt.incsearch = true

-- Splits ---------------------------------------------------------------------
opt.splitright = true        -- vertical splits open to the right
opt.splitbelow = true
opt.splitkeep = "screen"     -- don't scroll existing text when splitting

-- Files ----------------------------------------------------------------------
opt.undofile = true          -- undo history survives closing the file
opt.undolevels = 10000
opt.swapfile = false
opt.backup = false
opt.updatetime = 200         -- faster CursorHold -> quicker diagnostics/git signs
opt.timeoutlen = 400         -- how long which-key waits before showing itself
opt.confirm = true           -- prompt instead of failing on :q with unsaved changes

-- Completion -----------------------------------------------------------------
opt.completeopt = "menu,menuone,noselect"

-- Misc -----------------------------------------------------------------------
opt.mouse = "a"
opt.clipboard = "unnamedplus"  -- share the system clipboard with macOS
opt.inccommand = "split"       -- live preview of :%s/foo/bar
opt.virtualedit = "block"      -- let visual-block go past end of line
opt.shortmess:append("cI")     -- quieter messages, no intro screen

-- Diagnostics ----------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = { prefix = "●", spacing = 2 },
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN]  = " ",
      [vim.diagnostic.severity.HINT]  = " ",
      [vim.diagnostic.severity.INFO]  = " ",
    },
  },
})

-- Highlight text briefly when yanked, so you can see what you copied.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

-- Angular component templates get their own filetype so the Angular language
-- server and the `angular` treesitter parser both attach correctly.
vim.filetype.add({
  pattern = {
    [".*%.component%.html"] = "htmlangular",
  },
  filename = {
    ["Jenkinsfile"] = "groovy",
  },
  extension = {
    hcl = "hcl",
  },
})
