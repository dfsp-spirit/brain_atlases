#!/usr/bin/env bash
#
# Copy the fs_LR 32k template meshes and the fs_LR 32k cortical atlases from this
# repository into a FreeSurfer-compatible subjects_dir layout at the repo root, so
# the repo can serve directly as $SUBJECTS_DIR (e.g. for fsbrain or FreeSurfer tools).
#
# This script handles the fs_LR_32 subject only. The fsaverage subject is handled by
# the sibling script dev_tools/rearrange_fsaverage_into_subjects_dir.sh.
#
# The meshes are the FreeSurfer-format conversions of the original GIFTI meshes
# (see dev_tools/convert_fs_LR_32_mesh_to_surf.R). The generated files are NOT
# tracked in git (see .gitignore); this script only materializes them on your
# machine. Run it again to refresh after adding atlases.
#
# Usage (from the repository root):
#   bash dev_tools/rearrange_fs_LR_32_into_subjects_dir.sh
#
# Resulting layout:
#   subjects_dir/fs_LR_32/
#     surf/   # template meshes (pial, sphere, inflated, ...)
#     label/  # cortical atlas annotation files (lh/rh .annot)
#
# Then, e.g.:  export SUBJECTS_DIR="$PWD/subjects_dir"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"            # repository root (dev_tools/ is directly under it)
SUBJ_DIR="$REPO_ROOT/subjects_dir"                   # FreeSurfer subjects dir at the repo root
SUBJ="$SUBJ_DIR/fs_LR_32"

MESH_SRC="$REPO_ROOT/template_subject_meshes/fs_LR_32/converted_to_freesurfer_surf_format" # converted meshes
ATLAS_SRC="$REPO_ROOT/atlas_fs_LR_32"                # source fs_LR 32k annots

mkdir -p "$SUBJ/surf" "$SUBJ/label"

# 1. fs_LR 32k template surfaces
echo "== copying fs_LR 32k surfaces to $SUBJ/surf =="
shopt -s nullglob
files=( "$MESH_SRC"/lh.* "$MESH_SRC"/rh.* )
if [[ ${#files[@]} -eq 0 ]]; then
  echo "  (no files found in $MESH_SRC)"
fi

for f in "${files[@]}"; do
  cp "$f" "$SUBJ/surf/"
  echo "  surf/$(basename "$f")"
done

# 2. fs_LR 32k atlases (annot files) -> fs_LR_32/label
echo "== copying fs_LR 32k atlases to $SUBJ/label =="
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
