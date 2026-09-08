#!/usr/bin/env bash
#
# Turn the paintings in ~/Downloads into Neovim backgrounds.
#
#   ~/.config/nvim/terminal/paintings/import.sh [source-dir] [--force]
#
# Neovim cannot draw a background image -- it paints character cells, not
# pixels -- so the image comes from iTerm2 underneath, with the theme made
# transparent so it shows through. This script prepares what iTerm2 displays.
#
# It does NOT blend the painting over the ground at some opacity. That was the
# first approach and measuring it killed it: Graphite's ground is so dark that
# the brightest part of a sky hits the contrast floor at 2-3% opacity, which is
# indistinguishable from no painting at all. The limit is not "how much
# painting" but "how bright the background may get", and blending spends that
# whole budget on the few blown-out highlights.
#
# So instead each painting is TONE-MAPPED into the band the theme can afford:
# its darkest tone becomes the ground colour exactly, its brightest becomes the
# ceiling below, and everything in between is redistributed across that range.
# Same worst-case contrast, far more of the picture visible -- and because every
# painting is mapped into the same band, a near-black nocturne and a near-white
# river scene come out at the same weight, which is the point.
#
# The ceilings are not chosen by eye. Each is the furthest the ground can travel
# toward the theme's text colour while that theme's comment colour -- the
# lowest-contrast text it admits -- still clears WCAG 4.5:1, the same floor every
# colour in the palette was measured against. See `comment_on_painting` and
# `ceiling` in lua/scheme/palettes/<theme>.lua for the other half.
#
# EVERY THEME GETS ITS OWN RENDER. A painting mapped into one theme's band and
# shown behind another is wrong twice over: its darkest tone no longer equals the
# ground, so the image sits in a visible rectangle, and the 4.5:1 guarantee was
# solved against the wrong text colour. So the grounds, ceilings and comment
# colours are read out of the palette files rather than written here, and the
# output is named <slug>-<theme>-<variant>.png.
#
#   import.sh                 render every theme
#   import.sh --theme umber   just the one
#
# Safe to run repeatedly. Existing renders are kept; --force redoes them.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO/manifest.tsv"
OUT="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/paintings"

# The originals are committed here, so a fresh clone renders without hunting
# down eight paintings again. ~/Downloads is the inbox rather than the store:
# anything found there is copied in, ready to commit alongside its manifest
# line. They are the only binaries in this repo and the exception is deliberate
# -- 3MB once, against a config that otherwise cannot reproduce itself.
SRC="$REPO/src"

DOWNLOADS="$HOME/Downloads"
FORCE=0
ONLY_THEME=""
want_theme=0
for arg in "$@"; do
  if [[ $want_theme -eq 1 ]]; then ONLY_THEME="$arg"; want_theme=0; continue; fi
  case "$arg" in
    --force) FORCE=1 ;;
    --theme) want_theme=1 ;;
    --theme=*) ONLY_THEME="${arg#--theme=}" ;;
    *) DOWNLOADS="$arg" ;;
  esac
done

PALETTES="$(cd "$REPO/../../lua/scheme/palettes" && pwd)"

# Pull `ground`, `ceiling` and `comment_on_painting` out of one variant block of
# a palette file. The format is regular -- `key = "#hex",` inside `M.dark = {`
# or `M.light = {` -- so awk tracking which block it is inside is enough, and
# the script stays runnable without Neovim.
#
# The comment colour taken is `comment_on_painting`, the one that applies while a
# painting is showing, NOT the everyday `comment`.
palette_band() {
  local file=$1 variant=$2
  awk -v want="$variant" '
    /^M\.(dark|light) = \{/ {
      block = $0; sub(/^M\./, "", block); sub(/ .*/, "", block)
      inblock = (block == want); next
    }
    /^}/ { inblock = 0 }
    inblock && /^[[:space:]]*ground[[:space:]]*=/      { g = $0 }
    inblock && /^[[:space:]]*ceiling[[:space:]]*=/     { c = $0 }
    inblock && /^[[:space:]]*comment_on_painting[[:space:]]*=/ { t = $0 }
    END {
      if (g == "" || c == "" || t == "") exit 1
      for (i = 1; i <= 3; i++) {
        line = (i == 1 ? g : (i == 2 ? c : t))
        match(line, /#[0-9a-fA-F]{6}/)
        printf "%s%s", substr(line, RSTART, RLENGTH), (i < 3 ? " " : "\n")
      }
    }' "$file"
}

WCAG_FLOOR=4.5
GEOM="3840x2400"   # 16:10 at retina density; iTerm2 rescales to the window

failed=0
command -v magick >/dev/null 2>&1 || {
  printf 'ImageMagick is not installed -- brew bundle --file=~/.config/nvim/Brewfile\n' >&2
  exit 1
}

mkdir -p "$SRC" "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# sRGB transfer function and WCAG contrast, written once.
read -r -d '' AWK_LIB <<'AWK'
function lin(c) { return (c <= 0.04045) ? c / 12.92 : exp(2.4 * log((c + 0.055) / 1.055)) }
function lum(r, g, b) { return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) }
function ratio(l1, l2) {
  return (l1 > l2) ? (l1 + 0.05) / (l2 + 0.05) : (l2 + 0.05) / (l1 + 0.05)
}
AWK

hexchan() {
  local h=${1#\#}
  awk -v r="$((16#${h:0:2}))" -v g="$((16#${h:2:2}))" -v b="$((16#${h:4:2}))" \
    'BEGIN{printf "%.6f %.6f %.6f", r/255, g/255, b/255}'
}

# --- Rendering --------------------------------------------------------------

render() {
  local prepared=$1 dest=$2 ground=$3 ceiling=$4 comment=$5

  # +level-colors maps the image's black point to the first colour and its white
  # point to the second, which is exactly the tone-map we want: the darkest part
  # of the painting becomes the ground colour, so the image has no visible edge
  # against the rest of the editor.
  #
  # PNG8 is not a compromise here, it is the right format twice over. Squeezing
  # a painting into a band this narrow leaves about 30 distinct greys, and a
  # Dutch sky is nothing but gradient, so those steps would show as contour
  # lines; quantising to a palette applies error-diffusion dithering, which
  # scatters the steps below the threshold where the eye joins them into edges.
  # And because the result is a small palette rather than near-random noise, it
  # compresses: 1.4MB a file instead of the 17MB that adding Gaussian grain to
  # a truecolour PNG cost, for the same picture.
  if ! magick "$prepared" +level-colors "$ground","$ceiling" \
      -colors 256 -depth 8 -strip "PNG8:$dest" 2>/dev/null; then
    printf '  FAIL      %s\n' "$(basename "$dest")" >&2
    failed=1
    return
  fi

  # Measure the file just written rather than trusting the algebra. The blur is
  # the point: one stray pixel does not hurt readability, a region the width of
  # a line of text does.
  #
  # Both ends are measured because the two themes fail in opposite directions:
  # on the dark theme a bright sky is what closes on the text, on the light one
  # it is a dark mass of trees. Taking the worse of the two ratios covers both
  # without the script needing to know which theme it is rendering for.
  local hi lo achieved verdict
  read -r lo hi < <(magick "$dest" -resize 400x -colorspace Gray -blur 0x6 \
    -format '%[fx:minima] %[fx:maxima]' info: 2>/dev/null)
  achieved=$(awk -v tx="$(hexchan "$comment")" -v lo="$lo" -v hi="$hi" "$AWK_LIB"'
    BEGIN { split(tx, t, " ")
            lt = lum(t[1], t[2], t[3])
            a = ratio(lt, lum(lo, lo, lo)); b = ratio(lt, lum(hi, hi, hi))
            printf "%.2f", (a < b) ? a : b }')

  # The tolerance absorbs palette quantisation, which can round a pixel a step
  # past the ceiling. A hundredth of a ratio point is well inside the noise of
  # the measurement itself; anything worse than that is a real regression.
  verdict=$(awk -v a="$achieved" -v f="$WCAG_FLOOR" 'BEGIN{print (a + 0.02 >= f) ? "ok" : "BELOW FLOOR"}')
  [[ "$verdict" != "ok" ]] && failed=1
  printf '  %-40s %s:1  %s\n' "$(basename "$dest")" "$achieved" "$verdict"
}

# --- Main -------------------------------------------------------------------

# Which themes to render. One palette file each; ordered so the default comes
# first and a --force run shows it soonest.
THEMES=()
for f in "$PALETTES"/*.lua; do
  name="$(basename "$f" .lua)"
  [[ -n "$ONLY_THEME" && "$name" != "$ONLY_THEME" ]] && continue
  THEMES+=("$name")
done
if [[ ${#THEMES[@]} -eq 0 ]]; then
  printf 'No palettes matched%s in %s\n' \
    "${ONLY_THEME:+ \"$ONLY_THEME\"}" "${PALETTES/#$HOME/~}" >&2
  exit 1
fi

echo "Importing from ${DOWNLOADS/#$HOME/~}"
echo "Themes: ${THEMES[*]}"
echo
printf '  %-40s %s\n' "file" "comment contrast, measured"
printf '  %-40s %s\n' "----------------------------------------" "--------------------------"

while IFS=$'\t' read -r slug source label; do
  [[ "$slug" =~ ^# || -z "$slug" ]] && continue

  src="$SRC/$source"
  if [[ ! -f "$src" ]]; then
    if [[ -f "$DOWNLOADS/$source" ]]; then
      cp "$DOWNLOADS/$source" "$src"
      printf '  %-32s copied in from %s\n' "$slug" "${DOWNLOADS/#$HOME/~}"
    else
      printf '  MISSING   %s (%s) -- not in src/ or %s\n' \
        "$slug" "$source" "${DOWNLOADS/#$HOME/~}" >&2
      failed=1
      continue
    fi
  fi

  # Skip the (expensive) prepare step only when every theme already has both
  # variants -- otherwise a newly added theme would never get rendered.
  needed=0
  for theme in "${THEMES[@]}"; do
    [[ -f "$OUT/$slug-$theme-dark.png" && -f "$OUT/$slug-$theme-light.png" ]] || needed=1
  done
  if [[ $needed -eq 0 && $FORCE -eq 0 ]]; then
    printf '  %-40s already rendered for every theme\n' "$slug"
    continue
  fi

  # Scale, crop and desaturate once, then map from that. The saturation drop
  # keeps a warm Dutch sky from casting over Graphite's amber and sage syntax
  # accents; the tonal shape is what carries the picture at this strength
  # anyway. -normalize first so a painting that never reaches true black still
  # uses the whole band.
  prepared="$TMP/$slug.mpc"
  if ! magick "$src" -resize "${GEOM}^" -gravity center -extent "$GEOM" \
      -modulate 100,65 -normalize "$prepared" 2>/dev/null; then
    printf '  FAIL      %s could not be read\n' "$slug" >&2
    failed=1
    continue
  fi

  printf '  %s\n' "$label"
  for theme in "${THEMES[@]}"; do
    if ! read -r d_ground d_ceil d_comment < <(palette_band "$PALETTES/$theme.lua" dark) \
       || ! read -r l_ground l_ceil l_comment < <(palette_band "$PALETTES/$theme.lua" light); then
      printf '  %-40s could not read its band from %s.lua\n' "$theme" "$theme" >&2
      failed=1
      continue
    fi
    render "$prepared" "$OUT/$slug-$theme-dark.png"  "$d_ground" "$d_ceil"  "$d_comment"
    # Light: the painting darkens paper, so the ramp runs the other way -- the
    # painting's blacks become the ceiling and its whites become the ground.
    render "$prepared" "$OUT/$slug-$theme-light.png" "$l_ceil"   "$l_ground" "$l_comment"
  done
done < "$MANIFEST"

echo
count=$(find "$OUT" -maxdepth 1 -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
themes=${#THEMES[@]}
if [[ "$failed" -eq 0 ]]; then
  echo "Done. $count renders across $themes theme(s) -- <Space>ub in Neovim to pick one."
else
  echo "Finished with warnings above. $count renders written." >&2
  exit 1
fi
