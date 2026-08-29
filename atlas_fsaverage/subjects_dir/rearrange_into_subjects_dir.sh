#!/usr/bin/env bash
#
# Copy the fsaverage template meshes and the fsaverage cortical atlases from this
# repository into a FreeSurfer-compatible subjects_dir layout, so the repo can serve
# directly as $SUBJECTS_DIR (e.g. for fsbrain or FreeSurfer tools).
#
# The generated files are NOT tracked in git (see .gitignore); this script only
# materializes them on your machine. Run it again to refresh after adding atlases.
#
# Usage (from anywhere):
#   bash atlas_fsaverage/subjects_dir/rearrange_into_subjects_dir.sh
#
# Resulting layout:
#   atlas_fsaverage/subjects_dir/fsaverage/
#     surf/   # template meshes (inflated, pial, white, ...)
#     label/  # cortical atlas annotation files (lh/rh .annot)
#
# Then, e.g.:  export SUBJECTS_DIR="$PWD/atlas_fsaverage/subjects_dir"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJ_DIR="$SCRIPT_DIR"                                  # atlas_fsaverage/subjects_dir
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"            # repository root
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
echo "Done. The repo now serves as a FreeSurfer subjects dir:"
echo "  export SUBJECTS_DIR=\"$SUBJ_DIR\""
