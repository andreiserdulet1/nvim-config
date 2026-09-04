# Everything this Neovim config shells out to.
#
#   brew bundle --file=~/.config/nvim/Brewfile
#
# Language servers, formatters, linters and debug adapters are NOT here: Mason
# installs those into ~/.local/share/nvim/mason on first launch. Run
# `:checkhealth nvim-config` inside Neovim to see what is actually missing.

# --- Core: the config degrades quietly without these -----------------------
brew "neovim"           # 0.11+ required — the config uses vim.lsp.config()
brew "ripgrep"          # Telescope live grep, and grug-far's search & replace
brew "fd"               # Telescope file finding
brew "git-delta"        # side-by-side syntax-highlighted diffs inside lazygit
brew "tree-sitter-cli"  # nvim-treesitter's main branch compiles parsers with this
brew "lazygit"          # <leader>gg, the main git interface
brew "gh"               # GitHub PRs (<leader>p) and Actions (<leader>A)

# --- Infrastructure work ----------------------------------------------------
# terraform was removed from homebrew-core when its licence changed, so the tap
# is required: `brew install terraform` on its own fails.
tap "hashicorp/tap"
brew "hashicorp/tap/terraform"   # terraform-ls hover, and fmt on save

# --- Not installed here, on purpose ----------------------------------------
# tflint, js-debug-adapter, ngserver and every language server -> Mason
# node, yarn                                                   -> per project
