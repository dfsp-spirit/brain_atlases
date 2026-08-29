#!/usr/bin/env bash
#
# make_readme_previews.sh
# =======================
#
# Build the preview images embedded in the README "Gallery" section:
#
#   * One labeled overview montage per template (fsaverage 3x3, fs_LR 32k 4x2),
#     so readers can see all atlases "at a glance" in a single image.
#   * A downscaled clickable thumbnail for every atlas (these link to the
#     full-size 4-view render in the README).
#
# The full-size renders must exist first: run
#     Rscript dev_tools/visualize_all.R
# Output is written to <outdir>/previews/. These preview files ARE meant to be
# tracked in git, otherwise the images will not display on GitHub.
#
# Requires ImageMagick (montage + convert).
#
# Usage:
#   bash dev_tools/make_readme_previews.sh [outdir]
#   (outdir defaults to dev_tools/visualize_all_output)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="${1:-$SCRIPT_DIR/visualize_all_output}"
PREVIEWS="$OUTDIR/previews"
mkdir -p "$PREVIEWS"

if ! command -v montage >/dev/null 2>&1 || ! command -v convert >/dev/null 2>&1; then
  echo "ERROR: ImageMagick (montage/convert) not found on PATH." >&2
  exit 1
fi

FS_ATLASES=(HCPMMP1 aparc aal3 brainnetome schaefer100 schaefer200 schaefer300 schaefer400 schaefer1000)
LR_ATLASES=(aparc aal3 brainnetome schaefer100 schaefer200 schaefer300 schaefer400 schaefer1000)

echo "== labeled overview montages =="

# fsaverage: 3x3 grid
montage_args=()
for a in "${FS_ATLASES[@]}"; do
  montage_args+=( -label "$a" "$OUTDIR/fsaverage_$a.png" )
done
montage "${montage_args[@]}" -tile 3x3 -geometry 340x246+6+6 \
  -background black -fill white -pointsize 16 -depth 8 \
  -title "fsaverage atlases (4 views each)" \
  "$PREVIEWS/fsaverage_all.png"
echo "  wrote: $PREVIEWS/fsaverage_all.png"

# fs_LR 32k: 4x2 grid
montage_args=()
for a in "${LR_ATLASES[@]}"; do
  montage_args+=( -label "$a" "$OUTDIR/fsLR32_$a.png" )
done
montage "${montage_args[@]}" -tile 4x2 -geometry 300x217+6+6 \
  -background black -fill white -pointsize 14 -depth 8 \
  -title "fs_LR 32k atlases (4 views each)" \
  "$PREVIEWS/fslr32_all.png"
echo "  wrote: $PREVIEWS/fslr32_all.png"

echo "== clickable thumbnails =="
for f in "$OUTDIR"/fsaverage_*.png "$OUTDIR"/fsLR32_*.png; do
  b="$(basename "$f" .png)"
  convert "$f" -resize 480x "$PREVIEWS/${b}_thumb.png"
  echo "  wrote: $PREVIEWS/${b}_thumb.png"
done

echo
echo "Done. Preview files in: $PREVIEWS"
echo "Remember to git-add the preview files (and the full-size renders) so the"
echo "images display in the README on GitHub."
