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
