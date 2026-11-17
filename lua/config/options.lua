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

-- Folding --------------------------------------------------------------------
-- Treesitter knows where a method or a template block ends, so it folds far
-- better than indent does. Safe to set globally: foldexpr returns 0 for a
-- buffer with no parser, which means no folds rather than an error -- which is
-- also what happens to a file the bigfile guard has stripped treesitter from.
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldtext = ""            -- show the real line, highlighted, not "+--  12 lines"
opt.foldlevelstart = 99      -- files open unfolded; za closes what you want closed
-- "auto:1", not "1": the column appears only in a buffer that actually has
-- folds, so most files keep the gutter they had. Where it does appear, clicking
-- a marker opens or closes the fold -- folding without knowing za.
opt.foldcolumn = "auto:1"

-- Files ----------------------------------------------------------------------
opt.undofile = true          -- undo history survives closing the file
opt.undolevels = 10000
opt.swapfile = false
opt.backup = false
opt.updatetime = 200         -- faster CursorHold -> quicker diagnostics/git signs
opt.timeoutlen = 400         -- how long which-key waits before showing itself
opt.confirm = true           -- prompt instead of failing on :q with unsaved changes

-- persistence.nvim saves exactly what this names. The default includes
-- `terminal`, which restores the toggleterm floats, and `blank`, which restores
-- empty windows -- neither is worth carrying across a restart. `globals` is
-- left out on purpose: it would persist vim.g.disable_autoformat, so turning
-- format-on-save off once with <leader>uf would silently keep it off tomorrow.
opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize"

-- Completion -----------------------------------------------------------------
opt.completeopt = "menu,menuone,noselect"

-- Misc -----------------------------------------------------------------------
opt.mouse = "a"
-- Report pointer movement, not just clicks. Hover effects depend on it: the
-- close button that appears on the bufferline tab under the pointer, and
-- dropbar highlighting the crumb you are about to click.
opt.mousemoveevent = true
-- Finer than the default ver:3,hor:6, which overshoots on a trackpad.
opt.mousescroll = "ver:2,hor:4"
-- mousemodel stays at its default popup_setpos: right-click moves the cursor
-- first and then opens the menu, so the entries in config/menu.lua act on the
-- thing under the pointer rather than wherever the cursor happened to be.
opt.clipboard = "unnamedplus"  -- share the system clipboard with macOS
opt.inccommand = "split"       -- live preview of :%s/foo/bar
opt.virtualedit = "block"      -- let visual-block go past end of line
opt.shortmess:append("cI")     -- quieter messages, no intro screen

-- Icons ----------------------------------------------------------------------
-- Every icon in this config is a Nerd Font glyph, and a terminal not using a
-- patched font draws each one as a boxed question mark. This flag picks between
-- the glyphs and plain-text stand-ins; config/icons.lua holds both sets.
--
-- Set it to true once the glyph probe in `:checkhealth nvim-config` renders as
-- icons. It has to be set before any plugin spec is evaluated, which is why it
-- lives here rather than inside the module it controls.
vim.g.have_nerd_font = false

local icons = require("config.icons")

-- Diagnostics ----------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = { prefix = "●", spacing = 2 },
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = icons.diagnostic.error,
      [vim.diagnostic.severity.WARN]  = icons.diagnostic.warn,
      [vim.diagnostic.severity.HINT]  = icons.diagnostic.hint,
      [vim.diagnostic.severity.INFO]  = icons.diagnostic.info,
    },
  },
})

local function augroup(name)
  return vim.api.nvim_create_augroup(name, { clear = true })
end

-- Highlight text briefly when yanked, so you can see what you copied.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

-- Pick up files that changed underneath the editor. `autoread` is already on by
-- default, but it only re-reads when something asks, and `checktime` is the
-- ask -- so on its own it never fires. Claude, `ng generate`, lazygit branch
-- switches and prettier all write behind the buffer's back; without this the
-- stale text sits there until it collides with your next save.
--
-- TermClose/TermLeave are in the list because the <leader>n and <leader>ng
-- runners all finish inside a toggleterm float: stepping out of that float is
-- exactly the moment the tree on disk has moved.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermClose", "TermLeave" }, {
  group = augroup("reload_changed"),
  callback = function(ev)
    if vim.fn.mode() == "c" then return end           -- not mid command-line
    if vim.bo[ev.buf].buftype ~= "" then return end   -- not terminals or prompts
    if vim.api.nvim_buf_get_name(ev.buf) == "" then return end
    -- Scheduled deliberately. `checktime` inside an autocmd callback is blocked
    -- by the textlock and silently does nothing -- the buffer keeps the stale
    -- text and no error is raised. Deferring it out of the callback is what
    -- makes the re-read actually happen.
    vim.schedule(function() vim.cmd.checktime() end)
  end,
})

-- Say so, rather than silently swapping the text under the cursor.
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = augroup("reload_changed_notify"),
  callback = function()
    vim.notify("Reloaded — the file changed outside Neovim")
  end,
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

-- A CSV over snacks' 1.5 MB bigfile threshold gets filetype "bigfile", not
-- "csv", so csvview neither loads nor renders it automatically -- which is the
-- guard doing its job on an 11,000-row export. The manual toggle still works,
-- so say so instead of leaving you wondering why the table didn't appear.
--
-- This lives here rather than in csvview's own config because that config only
-- runs once csvview loads, and csvview never loads for a "bigfile" buffer.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "bigfile",
  callback = function(ev)
    local path = vim.api.nvim_buf_get_name(ev.buf)
    if not path:match("%.[ct]sv$") then return end
    vim.schedule(function()
      vim.notify(("%s is %.1f MB — press <leader>uv to render it as a table")
        :format(vim.fn.fnamemodify(path, ":t"), vim.fn.getfsize(path) / 1024 / 1024))
    end)
  end,
})

-- Reopen a file where you left it. Neovim records the last cursor position in
-- the `"` mark; this jumps to it. Skipped for commit and rebase buffers, where
-- the top of the file is always what you want.
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(ev)
    local exclude = { gitcommit = true, gitrebase = true, gitconfig = true }
    if exclude[vim.bo[ev.buf].filetype] or vim.b[ev.buf].last_pos_restored then
      return
    end
    vim.b[ev.buf].last_pos_restored = true
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
      vim.cmd("normal! zz")
    end
  end,
})

-- Spell-checking where the words are read by someone else: commit messages and
-- markdown, including the Jira comment composer. Code buffers are untouched.
--
-- The `modifiable` test is doing real work. jira.lua's comment composer and its
-- read-only issue view are both scratch buffers with filetype "markdown", so
-- buftype cannot separate them -- but the view is not modifiable. This spells
-- what you are writing and leaves what you are only reading alone.
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("prose"),
  pattern = { "markdown", "gitcommit" },
  callback = function(ev)
    if not vim.bo[ev.buf].modifiable then return end
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_gb"
  end,
})
