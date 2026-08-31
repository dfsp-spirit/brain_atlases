#!/usr/bin/env bash
#
# Copy the fsaverage template meshes and the fsaverage cortical atlases from this
# repository into a FreeSurfer-compatible subjects_dir layout at the repo root, so
# the repo can serve directly as $SUBJECTS_DIR (e.g. for fsbrain or FreeSurfer tools).
#
# This script handles the fsaverage subject only. The fs_LR 32k subject is handled
# by the sibling script dev_tools/rearrange_fs_LR_32_into_subjects_dir.sh.
#
# The generated files are NOT tracked in git (see .gitignore); this script only
# materializes them on your machine. Run it again to refresh after adding atlases.
#
# Usage (from the repository root):
#   bash dev_tools/rearrange_fsaverage_into_subjects_dir.sh
#
# Resulting layout:
#   subjects_dir/fsaverage/
#     surf/   # template meshes (inflated, pial, white, ...)
#     label/  # cortical atlas annotation files (lh/rh .annot)
#
# Then, e.g.:  export SUBJECTS_DIR="$PWD/subjects_dir"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"            # repository root (dev_tools/ is directly under it)
SUBJ_DIR="$REPO_ROOT/subjects_dir"                     # FreeSurfer subjects dir at the repo root
SUBJ="$SUBJ_DIR/fsaverage"

MESH_SRC="$REPO_ROOT/template_subject_meshes/fsaverage" # source template meshes
ATLAS_SRC="$REPO_ROOT/atlas_fsaverage"                  # source fsaverage annots

mkdir -p "$SUBJ/surf" "$SUBJ/label"

# 1. fsaverage template surfaces and labels
echo "== copying fsaverage files to $SUBJ =="
mkdir -p "$SUBJ/surf" "$SUBJ/label"

shopt -s nullglob
files=( "$MESH_SRC"/lh.* "$MESH_SRC"/rh.* )
if [[ ${#files[@]} -eq 0 ]]; then
  echo "  (no files found in $MESH_SRC)"
fi

for f in "${files[@]}"; do
  fname="$(basename "$f")"
  if [[ "$fname" == *.label ]]; then
    target_dir="label"
  else
    target_dir="surf"
  fi

  cp "$f" "$SUBJ/$target_dir/"
  echo "  $target_dir/$fname"
done

# 2. fsaverage atlases (annot files) -> fsaverage/label
echo "== copying fsaverage atlases to $SUBJ/label =="
annots=( "$ATLAS_SRC"/lh.*.annot "$ATLAS_SRC"/rh.*.annot )
if [[ ${#annots[@]} -eq 0 ]]; then
  echo "  (no .annot files found in $ATLAS_SRC)"
fi
for f in "${annots[@]}"; do
  cp "$f" "$SUBJ/label/"
  echo "  label/$(basename "$f")"
done

echo
cat <<EOF
Done. The repo now serves as a FreeSurfer subjects dir (with fsaverage and fs_LR_32):
  export SUBJECTS_DIR="$SUBJ_DIR"
EOF
