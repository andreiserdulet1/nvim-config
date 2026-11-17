# Everything this Neovim config shells out to.
#
#   brew bundle --file=~/.config/nvim/Brewfile
#
# Language servers, formatters, linters and debug adapters are NOT here: Mason
# installs those into ~/.local/share/nvim/mason on first launch. Run
# `:checkhealth nvim-config` inside Neovim to see what is actually missing.

# --- Core: the config degrades quietly without these -----------------------
brew "neovim"           # 0.12+ required — vim.lsp.config(), vim.lsp.document_color
brew "ripgrep"          # Telescope live grep, and grug-far's search & replace
brew "fd"               # Telescope file finding
brew "git-delta"        # side-by-side syntax-highlighted diffs inside lazygit
brew "tree-sitter-cli"  # nvim-treesitter's main branch compiles parsers with this
brew "lazygit"          # <leader>gg, the main git interface
brew "gh"               # GitHub PRs (<leader>p) and Actions (<leader>A)

# --- The font ---------------------------------------------------------------
# Every icon in this config is a Nerd Font glyph: the dashboard, the statusline
# separators, the git gutter, the diagnostic signs. Without a patched font they
# all render as question marks.
#
# Homebrew installs it; it cannot select it. Point the terminal at "MesloLGL
# Nerd Font Mono" afterwards, and run `:checkhealth nvim-config` to confirm --
# its Terminal section prints a glyph probe. If you already installed Meslo by
# hand, brew will tell you the files are there rather than overwriting them.
cask "font-meslo-lg-nerd-font"   # MesloLG Nerd Font, what this config is tuned for

# --- Jira -------------------------------------------------------------------
# The whole <leader>j layer shells out to this: sprint, board, transitions,
# assignment, comments. Its own config lives at ~/.config/.jira/.config.yml,
# outside this repo, and the API token comes from the macOS Keychain -- see the
# Jira section of the README. Nothing credential-shaped is committed here.
tap "ankitpokhrel/jira-cli"
brew "ankitpokhrel/jira-cli/jira-cli"

# --- Background paintings ---------------------------------------------------
# Only needed to RENDER the backgrounds: terminal/paintings/import.sh
# composites each painting over the theme's ground colour and writes the result
# to ~/.local/share/nvim/paintings. Neovim never shells out to it afterwards.
brew "imagemagick"      # terminal/paintings/import.sh

# --- Infrastructure work ----------------------------------------------------
# terraform was removed from homebrew-core when its licence changed, so the tap
# is required: `brew install terraform` on its own fails.
tap "hashicorp/tap"
brew "hashicorp/tap/terraform"   # terraform-ls hover, and fmt on save

# --- Not installed here, on purpose ----------------------------------------
# tflint, js-debug-adapter, ngserver and every language server -> Mason
# node, yarn                                                   -> per project
