#!/usr/bin/env bash
#
# Convert the cortical atlases from the fs_LR 32k (conte69) mesh to the FreeSurfer
# fsaverage mesh (163,842 vertices per hemisphere).
#
# Pipeline per hemisphere (lh/rh):
#   1. annot (fs_LR 32k)       -> label.gii (fs_LR 32k)     via FreeSurfer mris_convert
#   2. label.gii (fs_LR 32k)   -> label.gii (fsaverage)     via Connectome Workbench -label-resample
#   3. label.gii (fsaverage)   -> annot (fsaverage)         via R (convert_labelgii_to_annot.R)
#
# Requirements (no other software needed):
#   - Connectome Workbench (wb_command), path set in WB_COMMAND below.
#   - FreeSurfer (mris_convert), path set in FREESURFER_HOME below.
#   - R with the 'freesurferformats' and 'gifti' packages.
#
# Usage (from anywhere):
#   bash dev_tools/convert_fsLR32_to_fsaverage.sh
#
# Reads atlases from atlas_fs_LR_32/ and writes fsaverage annots to atlas_fsaverage/.

set -euo pipefail

# ---- settings (edit once) ------------------------------------------------------
WB_COMMAND="$HOME/software/connectome_workbench/workbench/bin_linux64/wb_command"
FREESURFER_HOME="${FREESURFER_HOME:-/home/ts/software/freesurfer/freesurfer7.4.1}"
FSAVERAGE_SUBJECT="$FREESURFER_HOME/subjects/fsaverage"

# ---- derived paths -------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ATLAS_SRC="$REPO_ROOT/atlas_fs_LR_32"     # source atlases (fs_LR 32k annots)
ATLAS_OUT="$REPO_ROOT/atlas_fsaverage"    # output atlases (fsaverage annots)
MESH_DIR="$REPO_ROOT/template_subject_meshes"
WORK="$(mktemp -d -t fslr2fsavg.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

MRIS_CONVERT="$FREESURFER_HOME/bin/mris_convert"
ATLASES=(aal3 aparc brainnetome schaefer100 schaefer200 schaefer300 schaefer400 schaefer1000)

mkdir -p "$ATLAS_OUT"

echo "== preparing fsaverage spheres and area surfaces =="
for HEMI in L R; do
  HEMI_LR=$([ "$HEMI" = "L" ] && echo lh || echo rh)
  "$MRIS_CONVERT" "$FSAVERAGE_SUBJECT/surf/${HEMI_LR}.sphere.reg" "$WORK/fsaverage.${HEMI}.sphere.surf.gii"
  "$MRIS_CONVERT" "$FSAVERAGE_SUBJECT/surf/${HEMI_LR}.white" "$WORK/fsaverage.${HEMI}.white.surf.gii"
done

for ATLAS in "${ATLASES[@]}"; do
  for HEMI in L R; do
    HEMI_LR=$([ "$HEMI" = "L" ] && echo lh || echo rh)

    # 1. annot (fs_LR 32k) -> label.gii (fs_LR 32k)
    "$MRIS_CONVERT" --annot "$ATLAS_SRC/${HEMI_LR}.${ATLAS}.annot" \
      "$MESH_DIR/fs_LR_32/fs_LR.32k.${HEMI}.midthickness.surf.gii" \
      "$WORK/${HEMI_LR}.${ATLAS}.label.gii"

    # 2. resample labels fs_LR 32k -> fsaverage
    "$WB_COMMAND" -label-resample "$WORK/${HEMI_LR}.${ATLAS}.label.gii" \
      "$MESH_DIR/fs_LR_32/fs_LR.32k.${HEMI}.sphere.surf.gii" \
      "$WORK/fsaverage.${HEMI}.sphere.surf.gii" \
      BARYCENTRIC \
      -area-surfs "$MESH_DIR/fs_LR_32/fs_LR.32k.${HEMI}.midthickness.surf.gii" \
                  "$WORK/fsaverage.${HEMI}.white.surf.gii" \
      "$WORK/${HEMI_LR}.${ATLAS}.fsaverage.label.gii"

    # 3. label.gii (fsaverage) -> annot (fsaverage)
    Rscript "$SCRIPT_DIR/convert_labelgii_to_annot.R" \
      "$WORK/${HEMI_LR}.${ATLAS}.fsaverage.label.gii" \
      "$ATLAS_OUT/${HEMI_LR}.${ATLAS}.annot"
  done
done

echo "DONE. fsaverage annots written to $ATLAS_OUT"
