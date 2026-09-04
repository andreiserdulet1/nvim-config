#!/usr/bin/env bash
#
# Link the terminal configs in this directory into place.
#
#   ~/.config/nvim/terminal/install.sh
#
# Safe to run repeatedly. Existing real files are backed up first, and a file
# that has diverged from the repo copy is REFUSED rather than overwritten -- if
# you edited one in place, this tells you instead of destroying the edit.
#
# ~/.zshrc is never touched; it holds machine-specific things (your aws-login
# alias, sdkman, PATH). The lines that matter are recorded in zshrc.snippet and
# only checked for below.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
failed=0

link() {
  local name=$1 dest=$2
  local src="$REPO/$name"

  if [[ ! -e "$src" ]]; then
    printf '  MISSING   %s is not in the repo\n' "$name" >&2
    failed=1
    return
  fi

  # Already linked correctly -- nothing to do.
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    printf '  ok        %s\n' "~${dest#"$HOME"}"
    return
  fi

  mkdir -p "$(dirname "$dest")"

  # A real file already there: only replace it if it matches, and keep a copy.
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    if ! diff -q "$dest" "$src" >/dev/null 2>&1; then
      printf '  DIVERGED  %s differs from terminal/%s -- not overwriting\n' \
        "~${dest#"$HOME"}" "$name" >&2
      printf '            copy your changes into the repo, or delete the file first\n' >&2
      diff -u "$src" "$dest" | sed -n '1,15p' | sed 's/^/            /' >&2
      failed=1
      return
    fi
    cp -p "$dest" "$dest.bak-$STAMP"
    printf '  backed up %s.bak-%s\n' "~${dest#"$HOME"}" "$STAMP"
  fi

  ln -sfn "$src" "$dest"
  printf '  linked    %s -> terminal/%s\n' "~${dest#"$HOME"}" "$name"
}

echo "Linking terminal configs from ${REPO/#$HOME/~}"
link tmux.conf     "$HOME/.tmux.conf"
link dev           "$HOME/.local/bin/dev"
link starship.toml "$HOME/.config/starship.toml"
link git-ignore    "$HOME/.config/git/ignore"

# ~/.zshrc is checked, never written.
echo
echo "Checking ~/.zshrc for the lines this setup relies on (not modifying it):"
check_zshrc() {
  local pattern=$1 label=$2
  if grep -q "$pattern" "$HOME/.zshrc" 2>/dev/null; then
    printf '  ok        %s\n' "$label"
  else
    printf '  MISSING   %s -- see terminal/zshrc.snippet\n' "$label"
    failed=1
  fi
}
check_zshrc 'starship init'  'starship prompt'
check_zshrc 'zoxide init'    'zoxide'
check_zshrc 'fzf'            'fzf key bindings'
check_zshrc 'direnv hook'    'direnv hook'
check_zshrc 'EDITOR'         'EDITOR=nvim'
check_zshrc 'local/bin'      '~/.local/bin on PATH (needed for `dev`)'

echo
if [[ "$failed" -eq 0 ]]; then
  echo "Done. Open a new shell, then try: dev"
else
  echo "Finished with warnings above." >&2
  exit 1
fi
