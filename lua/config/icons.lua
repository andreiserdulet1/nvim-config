-- Two spellings for every icon in this config.
--
-- A terminal that is not using a patched font draws each Nerd Font glyph as a
-- boxed question mark, which normally forces a choice between "has icons" and
-- "works anywhere". Keeping both spellings and switching on a flag means
-- neither has to be given up: the statusline stays readable over ssh or in a
-- terminal you do not control, and turns back into icons the moment the font
-- is there.
--
-- The flag is `vim.g.have_nerd_font`, set in config/options.lua, which runs
-- before any plugin spec is evaluated. Flip it to true once the glyph probe in
-- `:checkhealth nvim-config` renders as icons rather than question marks.
--
-- Codepoints are written in the comments deliberately. Every icon slot in this
-- config was an empty string until it was filled in, and a glyph that gets
-- lost again is invisible in a diff -- the codepoint is what makes it
-- recoverable.

local nerd = vim.g.have_nerd_font == true

-- Not switched, and deliberately so: the gitsigns marks (▎ ▁ ▔, U+258E U+2581
-- U+2594) are Block Elements rather than private-use glyphs, so they render in
-- an unpatched font too. The gutter is the signal you read constantly, and it
-- should survive whatever the terminal is doing.

local NERD = {
  -- U+EA87 U+EA6C U+EA61 U+EA74 -- codicons, carried by every Nerd Font version
  diagnostic = { error = " ", warn = " ", hint = " ", info = " " },

  -- U+E0B0 U+E0B2 solid, U+E0B1 U+E0B3 thin
  separator = {
    section_left = "", section_right = "",
    component_left = "", component_right = "",
  },

  lsp = " ", -- U+F085

  dashboard = {
    find       = " ", -- U+F002
    new        = " ", -- U+F15B
    grep       = " ", -- U+F002
    recent     = " ", -- U+F1DA
    projects   = " ", -- U+F07B
    cheatsheet = " ", -- U+F02D
    jira       = " ", -- U+F0AE
    plugins    = "󰒲 ", -- U+F04B2
    quit       = " ", -- U+F011
  },

  -- U+E5FF U+E5FE U+F114 -- seti folders, then fa folder-o for an empty one
  folder = { closed = "", open = "", empty = "" },

  git_status = {
    added     = "",     -- U+F067
    modified  = "",  -- U+F044
    deleted   = "✖",   -- U+2716, renders anywhere
    renamed   = "󰁕",   -- U+F0055
    untracked = "", -- U+F005, a star: "new". U+F128 was a question mark, which read as "broken icon"
    ignored   = "",   -- U+F070
    unstaged  = "󰄱",  -- U+F0131
    staged    = "",    -- U+F00C
    conflict  = "",  -- U+F071
  },
}

local TEXT = {
  diagnostic = { error = "E ", warn = "W ", hint = "H ", info = "I " },

  -- Lualine's plain look: no section separator at all, a thin bar between
  -- components. U+2502 is a box-drawing character, present in any monospace font.
  separator = {
    section_left = "", section_right = "",
    component_left = "│", component_right = "│",
  },

  lsp = "",

  -- The dashboard reads fine without them -- each row already has a key and a
  -- label, so an icon column of punctuation would be noise rather than help.
  dashboard = {
    find = "", new = "", grep = "", recent = "", projects = "",
    cheatsheet = "", jira = "", plugins = "", quit = "",
  },

  folder = { closed = "▸", open = "▾", empty = "▹" },

  git_status = {
    added = "+", modified = "~", deleted = "x", renamed = ">",
    untracked = "*", ignored = "·", unstaged = "!", staged = "✓", conflict = "!",
  },
}

return nerd and NERD or TEXT
