-- Graphite: highlight construction.
--
-- Roughly a hundred base groups are defined here and Neovim's own default
-- links carry the rest -- a session has 827 live highlight groups and 160
-- treesitter captures, so defining every one by hand would be unmaintainable
-- and would drift the moment a plugin changed.
--
-- The hue assignment is the actual design decision, and it is deliberate:
--
--   amber  functions and methods -- what you scan a file for
--   clay   keywords and control flow
--   sage   strings
--   slate  numbers, booleans, constants
--   ochre  types, classes, interfaces
--   text   variables and properties, left uncoloured to keep the noise down
--
-- Operators and punctuation get dim text rather than a hue of their own.

local M = {}

---@param p table palette
---@return table<string, vim.api.keyset.highlight>
function M.highlights(p)
  local none = "NONE"

  local groups = {
    ----------------------------------------------------------------------
    -- Editor
    ----------------------------------------------------------------------
    Normal       = { fg = p.text, bg = p.ground },
    NormalNC     = { fg = p.text, bg = p.ground },
    NormalFloat  = { fg = p.text, bg = p.surface },
    FloatBorder  = { fg = p.border, bg = p.surface },
    FloatTitle   = { fg = p.amber, bg = p.surface, bold = true },
    ColorColumn  = { bg = p.raised },
    Conceal      = { fg = p.gutter },
    Cursor       = { fg = p.ground, bg = p.text },
    lCursor      = { link = "Cursor" },
    CursorIM     = { link = "Cursor" },
    CursorLine   = { bg = p.raised },
    CursorColumn = { bg = p.raised },
    Directory    = { fg = p.amber },
    EndOfBuffer  = { fg = p.ground },
    ErrorMsg     = { fg = p.rose, bold = true },
    VertSplit    = { fg = p.border },
    WinSeparator = { fg = p.border },
    Folded       = { fg = p.dim, bg = p.raised },
    FoldColumn   = { fg = p.gutter, bg = none },
    SignColumn   = { fg = p.gutter, bg = none },
    IncSearch    = { fg = p.ground, bg = p.amber },
    CurSearch    = { link = "IncSearch" },
    Search       = { fg = p.text, bg = p.selection },
    Substitute   = { fg = p.ground, bg = p.rose },
    LineNr       = { fg = p.gutter },
    CursorLineNr = { fg = p.amber, bold = true },
    MatchParen   = { fg = p.amber, bold = true, underline = true },
    ModeMsg      = { fg = p.dim, bold = true },
    MsgArea      = { fg = p.text },
    MoreMsg      = { fg = p.amber },
    NonText      = { fg = p.gutter },
    Pmenu        = { fg = p.text, bg = p.surface },
    PmenuSel     = { bg = p.selection, bold = true },
    PmenuSbar    = { bg = p.surface },
    PmenuThumb   = { bg = p.border },
    Question     = { fg = p.amber },
    QuickFixLine = { bg = p.selection, bold = true },
    SpecialKey   = { fg = p.gutter },
    StatusLine   = { fg = p.text, bg = p.surface },
    StatusLineNC = { fg = p.gutter, bg = p.surface },
    TabLine      = { fg = p.dim, bg = p.surface },
    TabLineFill  = { bg = p.ground },
    TabLineSel   = { fg = p.text, bg = p.raised, bold = true },
    Title        = { fg = p.amber, bold = true },
    Visual       = { bg = p.selection },
    VisualNOS    = { bg = p.selection },
    WarningMsg   = { fg = p.ochre },
    Whitespace   = { fg = p.gutter },
    WildMenu     = { bg = p.selection },
    Winbar       = { fg = p.dim, bg = none },
    WinbarNC     = { fg = p.gutter, bg = none },

    ----------------------------------------------------------------------
    -- Syntax
    ----------------------------------------------------------------------
    Comment        = { fg = p.comment, italic = true },
    Constant       = { fg = p.slate },
    String         = { fg = p.sage },
    Character      = { fg = p.sage },
    Number         = { fg = p.slate },
    Boolean        = { fg = p.slate },
    Float          = { fg = p.slate },
    Identifier     = { fg = p.text },
    Function       = { fg = p.amber },
    Statement      = { fg = p.clay },
    Conditional    = { fg = p.clay },
    Repeat         = { fg = p.clay },
    Label          = { fg = p.clay },
    Operator       = { fg = p.dim },
    Keyword        = { fg = p.clay },
    Exception      = { fg = p.clay },
    PreProc        = { fg = p.clay },
    Include        = { fg = p.clay },
    Define         = { fg = p.clay },
    Macro          = { fg = p.clay },
    PreCondit      = { fg = p.clay },
    Type           = { fg = p.ochre },
    StorageClass   = { fg = p.clay },
    Structure      = { fg = p.ochre },
    Typedef        = { fg = p.ochre },
    Special        = { fg = p.amber },
    SpecialChar    = { fg = p.clay },
    Tag            = { fg = p.clay },
    Delimiter      = { fg = p.dim },
    SpecialComment = { fg = p.comment, bold = true },
    Debug          = { fg = p.rose },
    Underlined     = { underline = true },
    Bold           = { bold = true },
    Italic         = { italic = true },
    Error          = { fg = p.rose },
    Todo           = { fg = p.ground, bg = p.ochre, bold = true },

    ----------------------------------------------------------------------
    -- Treesitter: only where the default link would be wrong
    ----------------------------------------------------------------------
    ["@variable"]              = { fg = p.text },
    ["@variable.builtin"]      = { fg = p.clay, italic = true },
    ["@variable.parameter"]    = { fg = p.text },
    ["@variable.member"]       = { fg = p.text },
    ["@property"]              = { fg = p.text },
    ["@field"]                 = { fg = p.text },
    ["@constant"]              = { fg = p.slate },
    ["@constant.builtin"]      = { fg = p.slate, italic = true },
    ["@module"]                = { fg = p.ochre },
    ["@function"]              = { fg = p.amber },
    ["@function.builtin"]      = { fg = p.amber, italic = true },
    ["@function.method"]       = { fg = p.amber },
    ["@constructor"]           = { fg = p.ochre },
    ["@keyword"]               = { fg = p.clay },
    ["@keyword.import"]        = { fg = p.clay },
    ["@keyword.return"]        = { fg = p.clay, bold = true },
    ["@type"]                  = { fg = p.ochre },
    ["@type.builtin"]          = { fg = p.ochre, italic = true },
    ["@string"]                = { fg = p.sage },
    ["@string.escape"]         = { fg = p.clay },
    ["@string.special"]        = { fg = p.clay },
    ["@number"]                = { fg = p.slate },
    ["@boolean"]               = { fg = p.slate },
    ["@operator"]              = { fg = p.dim },
    ["@punctuation.delimiter"] = { fg = p.dim },
    ["@punctuation.bracket"]   = { fg = p.dim },
    ["@punctuation.special"]   = { fg = p.clay },
    ["@comment"]               = { fg = p.comment, italic = true },
    ["@comment.todo"]          = { fg = p.ground, bg = p.ochre, bold = true },
    ["@comment.warning"]       = { fg = p.ground, bg = p.ochre, bold = true },
    ["@comment.error"]         = { fg = p.ground, bg = p.rose, bold = true },
    ["@comment.note"]          = { fg = p.ground, bg = p.slate, bold = true },
    ["@tag"]                   = { fg = p.clay },
    ["@tag.builtin"]           = { fg = p.clay },
    ["@tag.attribute"]         = { fg = p.amber },
    ["@tag.delimiter"]         = { fg = p.dim },
    ["@markup.heading"]        = { fg = p.amber, bold = true },
    ["@markup.raw"]            = { fg = p.sage },
    ["@markup.link"]           = { fg = p.slate, underline = true },
    ["@markup.list"]           = { fg = p.clay },
    ["@markup.strong"]         = { bold = true },
    ["@markup.italic"]         = { italic = true },
    ["@diff.plus"]             = { fg = p.add_fg },
    ["@diff.minus"]            = { fg = p.delete_fg },
    ["@diff.delta"]            = { fg = p.change_fg },

    -- LSP semantic tokens follow the treesitter captures
    ["@lsp.type.class"]         = { link = "@type" },
    ["@lsp.type.interface"]     = { link = "@type" },
    ["@lsp.type.enum"]          = { link = "@type" },
    ["@lsp.type.function"]      = { link = "@function" },
    ["@lsp.type.method"]        = { link = "@function.method" },
    ["@lsp.type.property"]      = { link = "@property" },
    ["@lsp.type.parameter"]     = { link = "@variable.parameter" },
    ["@lsp.type.variable"]      = { link = "@variable" },
    ["@lsp.type.namespace"]     = { link = "@module" },
    ["@lsp.type.decorator"]     = { fg = p.amber, italic = true },
    ["@lsp.mod.readonly"]       = { fg = p.slate },
    ["@lsp.mod.deprecated"]     = { strikethrough = true },

    ----------------------------------------------------------------------
    -- Diagnostics
    ----------------------------------------------------------------------
    DiagnosticError          = { fg = p.rose },
    DiagnosticWarn           = { fg = p.ochre },
    DiagnosticInfo           = { fg = p.slate },
    DiagnosticHint           = { fg = p.sage },
    DiagnosticOk             = { fg = p.sage },
    DiagnosticUnderlineError = { undercurl = true, sp = p.rose },
    DiagnosticUnderlineWarn  = { undercurl = true, sp = p.ochre },
    DiagnosticUnderlineInfo  = { undercurl = true, sp = p.slate },
    DiagnosticUnderlineHint  = { undercurl = true, sp = p.sage },
    DiagnosticVirtualTextError = { fg = p.rose },
    DiagnosticVirtualTextWarn  = { fg = p.ochre },
    DiagnosticVirtualTextInfo  = { fg = p.slate },
    DiagnosticVirtualTextHint  = { fg = p.sage },
    LspReferenceText         = { bg = p.selection },
    LspReferenceRead         = { bg = p.selection },
    LspReferenceWrite        = { bg = p.selection, underline = true },
    LspInlayHint             = { fg = p.gutter, italic = true },
    LspSignatureActiveParameter = { fg = p.amber, bold = true },

    ----------------------------------------------------------------------
    -- Diff and git
    ----------------------------------------------------------------------
    DiffAdd    = { bg = p.add_bg },
    DiffChange = { bg = p.change_bg },
    DiffDelete = { bg = p.delete_bg },
    DiffText   = { bg = p.change_bg, bold = true },
    diffAdded   = { fg = p.add_fg },
    diffRemoved = { fg = p.delete_fg },
    diffChanged = { fg = p.change_fg },
    diffFile    = { fg = p.amber },
    diffLine    = { fg = p.slate },

    GitSignsAdd          = { fg = p.add_fg },
    GitSignsChange       = { fg = p.change_fg },
    GitSignsDelete       = { fg = p.delete_fg },
    GitSignsAddInline    = { bg = p.add_bg },
    GitSignsChangeInline = { bg = p.change_bg },
    GitSignsDeleteInline = { bg = p.delete_bg },
    GitSignsCurrentLineBlame = { fg = p.gutter, italic = true },

    -- git-conflict: the three regions must be tellable apart at a glance
    GitConflictCurrent      = { bg = p.add_bg },
    GitConflictIncoming     = { bg = p.change_bg },
    GitConflictAncestor     = { bg = p.raised },
    GitConflictCurrentLabel = { bg = p.add_bg, fg = p.add_fg, bold = true },
    GitConflictIncomingLabel = { bg = p.change_bg, fg = p.change_fg, bold = true },
    GitConflictAncestorLabel = { bg = p.raised, fg = p.dim, bold = true },

    ----------------------------------------------------------------------
    -- Plugins that do not link sensibly to the base groups
    ----------------------------------------------------------------------
    -- Telescope: card on ground, matching the guide's layering
    TelescopeNormal       = { fg = p.text, bg = p.surface },
    TelescopeBorder       = { fg = p.border, bg = p.surface },
    TelescopeTitle        = { fg = p.ground, bg = p.amber, bold = true },
    TelescopePromptNormal = { fg = p.text, bg = p.raised },
    TelescopePromptBorder = { fg = p.raised, bg = p.raised },
    TelescopePromptTitle  = { fg = p.ground, bg = p.amber, bold = true },
    TelescopePromptPrefix = { fg = p.amber },
    TelescopeResultsTitle = { fg = p.surface, bg = p.surface },
    TelescopePreviewTitle = { fg = p.ground, bg = p.sage, bold = true },
    TelescopeSelection    = { bg = p.selection, bold = true },
    TelescopeMatching     = { fg = p.amber, bold = true },

    -- neo-tree
    NeoTreeNormal        = { fg = p.text, bg = p.surface },
    NeoTreeNormalNC      = { fg = p.text, bg = p.surface },
    NeoTreeWinSeparator  = { fg = p.border, bg = p.surface },
    NeoTreeEndOfBuffer   = { fg = p.surface, bg = p.surface },
    NeoTreeRootName      = { fg = p.amber, bold = true },
    NeoTreeDirectoryName = { fg = p.text },
    NeoTreeDirectoryIcon = { fg = p.amber },
    NeoTreeFileName      = { fg = p.text },
    NeoTreeFileIcon      = { fg = p.dim },
    NeoTreeIndentMarker  = { fg = p.gutter },
    NeoTreeGitAdded      = { fg = p.add_fg },
    NeoTreeGitModified   = { fg = p.change_fg },
    NeoTreeGitDeleted    = { fg = p.delete_fg },
    NeoTreeGitUntracked  = { fg = p.comment, italic = true },
    NeoTreeGitIgnored    = { fg = p.gutter },
    NeoTreeTabActive     = { fg = p.amber, bg = p.surface, bold = true },
    NeoTreeTabInactive   = { fg = p.gutter, bg = p.ground },

    -- bufferline
    BufferLineFill              = { bg = p.ground },
    BufferLineBackground        = { fg = p.gutter, bg = p.ground },
    BufferLineBufferSelected    = { fg = p.text, bg = p.raised, bold = true, italic = false },
    BufferLineBufferVisible     = { fg = p.dim, bg = p.ground },
    BufferLineSeparator         = { fg = p.ground, bg = p.ground },
    BufferLineSeparatorSelected = { fg = p.ground, bg = p.raised },
    BufferLineSeparatorVisible  = { fg = p.ground, bg = p.ground },
    BufferLineIndicatorSelected = { fg = p.amber, bg = p.raised },
    BufferLineModified          = { fg = p.change_fg, bg = p.ground },
    BufferLineModifiedSelected  = { fg = p.change_fg, bg = p.raised },
    BufferLineErrorSelected     = { fg = p.rose, bg = p.raised, bold = true },
    BufferLineWarningSelected   = { fg = p.ochre, bg = p.raised, bold = true },
    BufferLinePickSelected      = { fg = p.amber, bg = p.raised, bold = true },

    -- dropbar (breadcrumbs)
    DropBarIconKindFunction = { fg = p.amber },
    DropBarIconKindClass    = { fg = p.ochre },
    DropBarIconKindProperty = { fg = p.text },
    DropBarIconUISeparator  = { fg = p.gutter },
    DropBarCurrentContext   = { bg = p.selection },
    DropBarMenuNormalFloat  = { fg = p.text, bg = p.surface },
    DropBarMenuHoverEntry   = { bg = p.selection },

    -- blink.cmp
    BlinkCmpMenu           = { fg = p.text, bg = p.surface },
    BlinkCmpMenuBorder     = { fg = p.border, bg = p.surface },
    BlinkCmpMenuSelection  = { bg = p.selection, bold = true },
    BlinkCmpLabelMatch     = { fg = p.amber, bold = true },
    BlinkCmpLabelDeprecated = { fg = p.gutter, strikethrough = true },
    BlinkCmpKind           = { fg = p.dim },
    BlinkCmpKindFunction   = { fg = p.amber },
    BlinkCmpKindClass      = { fg = p.ochre },
    BlinkCmpKindVariable   = { fg = p.text },
    BlinkCmpKindKeyword    = { fg = p.clay },
    BlinkCmpDoc            = { fg = p.text, bg = p.surface },
    BlinkCmpDocBorder      = { fg = p.border, bg = p.surface },
    BlinkCmpGhostText      = { fg = p.gutter, italic = true },

    -- trouble
    TroubleNormal   = { fg = p.text, bg = p.surface },
    TroubleText     = { fg = p.text },
    TroubleCount    = { fg = p.amber, bold = true },
    TroubleSource   = { fg = p.comment },
    TroubleFoldIcon = { fg = p.gutter },

    -- which-key
    WhichKey          = { fg = p.amber, bold = true },
    WhichKeyGroup     = { fg = p.clay },
    WhichKeyDesc      = { fg = p.text },
    WhichKeySeparator = { fg = p.gutter },
    WhichKeyFloat     = { bg = p.surface },
    WhichKeyBorder    = { fg = p.border, bg = p.surface },
    WhichKeyTitle     = { fg = p.ground, bg = p.amber, bold = true },

    -- diffview
    DiffviewNormal          = { fg = p.text, bg = p.surface },
    DiffviewFilePanelTitle  = { fg = p.amber, bold = true },
    DiffviewFilePanelCounter = { fg = p.slate },
    DiffviewFilePanelFileName = { fg = p.text },
    DiffviewStatusAdded     = { fg = p.add_fg },
    DiffviewStatusModified  = { fg = p.change_fg },
    DiffviewStatusDeleted   = { fg = p.delete_fg },
    DiffviewStatusUntracked = { fg = p.comment },
    DiffviewDim1            = { fg = p.gutter },

    -- csvview: alternating columns must be distinguishable but quiet
    CsvViewDelimiter = { fg = p.gutter },
    CsvViewComment   = { fg = p.comment, italic = true },
    CsvViewHeaderLine = { bg = p.raised, bold = true },
    CsvViewStickyHeaderSeparator = { fg = p.border },
    CsvViewCol0 = { fg = p.text },
    CsvViewCol1 = { fg = p.slate },
    CsvViewCol2 = { fg = p.sage },
    CsvViewCol3 = { fg = p.ochre },
    CsvViewCol4 = { fg = p.clay },
    CsvViewCol5 = { fg = p.amber },
    CsvViewCol6 = { fg = p.dim },
    CsvViewCol7 = { fg = p.comment },
    CsvViewCol8 = { fg = p.text },

    -- nvim-dap-ui
    DapUINormal          = { fg = p.text, bg = p.surface },
    DapUIVariable        = { fg = p.text },
    DapUIValue           = { fg = p.sage },
    DapUIType            = { fg = p.ochre },
    DapUIScope           = { fg = p.amber, bold = true },
    DapUIDecoration      = { fg = p.border },
    DapUIThread          = { fg = p.sage },
    DapUIStoppedThread   = { fg = p.amber },
    DapUIBreakpointsPath = { fg = p.slate },
    DapUIBreakpointsInfo = { fg = p.sage },
    DapUIBreakpointsCurrentLine = { fg = p.amber, bold = true },
    DapUILineNumber      = { fg = p.gutter },
    DapUIWatchesEmpty    = { fg = p.gutter },
    DapUIWatchesValue    = { fg = p.sage },
    DapUIWatchesError    = { fg = p.rose },
    DapUISource          = { fg = p.amber },
    DapUIFloatBorder     = { fg = p.border, bg = p.surface },
    DapStoppedLine       = { bg = p.change_bg },

    -- render-markdown
    RenderMarkdownH1Bg   = { fg = p.amber, bg = p.raised, bold = true },
    RenderMarkdownH2Bg   = { fg = p.ochre, bg = p.raised, bold = true },
    RenderMarkdownH3Bg   = { fg = p.sage, bg = p.raised, bold = true },
    RenderMarkdownH4Bg   = { fg = p.slate, bg = p.raised },
    RenderMarkdownH5Bg   = { fg = p.clay, bg = p.raised },
    RenderMarkdownH6Bg   = { fg = p.dim, bg = p.raised },
    RenderMarkdownCode   = { bg = p.surface },
    RenderMarkdownBullet = { fg = p.clay },
    RenderMarkdownQuote  = { fg = p.comment },
    RenderMarkdownTableHead = { fg = p.amber },
    RenderMarkdownTableRow  = { fg = p.dim },

    -- flash
    FlashLabel   = { fg = p.ground, bg = p.amber, bold = true },
    FlashMatch   = { fg = p.text, bg = p.selection },
    FlashCurrent = { fg = p.ground, bg = p.clay, bold = true },
    FlashBackdrop = { fg = p.gutter },

    -- multicursor
    MultiCursorCursor         = { reverse = true },
    MultiCursorVisual         = { bg = p.selection },
    MultiCursorSign           = { fg = p.amber },
    MultiCursorMatchPreview   = { bg = p.change_bg },
    MultiCursorDisabledCursor = { fg = p.dim, reverse = true },
    MultiCursorDisabledVisual = { bg = p.raised },
    MultiCursorDisabledSign   = { fg = p.gutter },

    -- snacks: indent guides and the dashboard
    SnacksIndent      = { fg = p.raised },
    SnacksIndentScope = { fg = p.border },
    SnacksDashboardHeader = { fg = p.amber, bold = true },
    SnacksDashboardIcon   = { fg = p.clay },
    SnacksDashboardDesc   = { fg = p.text },
    SnacksDashboardKey    = { fg = p.ochre, bold = true },
    SnacksDashboardFooter = { fg = p.comment },
    SnacksNotifierInfo    = { fg = p.slate, bg = p.surface },
    SnacksNotifierWarn    = { fg = p.ochre, bg = p.surface },
    SnacksNotifierError   = { fg = p.rose, bg = p.surface },
    SnacksNotifierBorderInfo = { fg = p.border, bg = p.surface },

    -- undotree, grug-far, octo
    UndotreeCurrent = { fg = p.amber, bold = true },
    UndotreeNode    = { fg = p.slate },
    UndotreeSeq     = { fg = p.gutter },
    GrugFarHelpHeader = { fg = p.amber, bold = true },
    GrugFarResultsMatch = { fg = p.amber, bold = true },
    GrugFarResultsPath  = { fg = p.slate, underline = true },
    OctoGreen = { fg = p.sage },
    OctoRed   = { fg = p.rose },
    OctoPurple = { fg = p.slate },
    OctoYellow = { fg = p.ochre },

    -- the cheatsheet buffer uses Title/Statement/Comment, already covered
  }

  ------------------------------------------------------------------------
  -- Transparency
  ------------------------------------------------------------------------
  -- Set by init.lua when a background painting is available, so the terminal
  -- shows through the editing canvas. Four groups is the whole change:
  -- SignColumn, FoldColumn and Winbar are already NONE above and inherit from
  -- Normal, so they come along for free.
  --
  -- What stays opaque is the deliberate half. Floats, popups, the completion
  -- menu, the statusline and the Telescope surfaces are where you most need
  -- text to be unambiguous, and a solid `surface` behind them costs nothing
  -- visually. CursorLine keeps its fill too, which gives a clean band under the
  -- line being edited.
  if vim.g.graphite_transparent then
    groups.Normal.bg = none
    groups.NormalNC.bg = none
    groups.TabLineFill.bg = none

    -- EndOfBuffer hides the `~` markers by painting them the background colour.
    -- That trick needs a background to match, and there isn't one any more, so
    -- they become a faint gutter mark instead of ground-coloured text sitting
    -- visibly on top of a painting.
    groups.EndOfBuffer = { fg = p.gutter, bg = none }
  end

  return groups
end

--- Apply Graphite for the current `background`.
function M.load()
  local palette = require("graphite.palette").get()

  -- A background painting lifts the ground colour, which costs comments most of
  -- their contrast margin. Swapping the palette entry rather than the handful
  -- of highlight groups means every group that reads `comment` -- Comment,
  -- @comment, NeoTreeGitUntracked, the dashboard footer and a dozen others --
  -- follows automatically and cannot drift apart.
  if vim.g.graphite_transparent then
    palette = vim.tbl_extend("force", palette, { comment = palette.comment_on_painting })
  end

  if vim.g.colors_name then vim.cmd("hi clear") end
  if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end

  vim.g.colors_name = "graphite"
  vim.o.termguicolors = true

  for group, spec in pairs(M.highlights(palette)) do
    vim.api.nvim_set_hl(0, group, spec)
  end

  -- Terminal colours, so :terminal and lazygit inside it agree with the theme.
  vim.g.terminal_color_0  = palette.ground
  vim.g.terminal_color_1  = palette.rose
  vim.g.terminal_color_2  = palette.sage
  vim.g.terminal_color_3  = palette.ochre
  vim.g.terminal_color_4  = palette.slate
  vim.g.terminal_color_5  = palette.clay
  vim.g.terminal_color_6  = palette.amber
  vim.g.terminal_color_7  = palette.text
  vim.g.terminal_color_8  = palette.gutter
  vim.g.terminal_color_9  = palette.rose
  vim.g.terminal_color_10 = palette.sage
  vim.g.terminal_color_11 = palette.ochre
  vim.g.terminal_color_12 = palette.slate
  vim.g.terminal_color_13 = palette.clay
  vim.g.terminal_color_14 = palette.amber
  vim.g.terminal_color_15 = palette.text
end

return M
