#!/usr/bin/env bash
#
# Convert the cortical atlases from the fs_LR 32k (conte69) mesh to the FreeSurfer
# fsaverage mesh (163,842 vertices per hemisphere).
#
# Pipeline per hemisphere (lh/rh):
#   1. annot (fs_LR 32k)        -> label.gii (fs_LR 32k)       via FreeSurfer mris_convert
#   2. label.gii (fs_LR 32k)    -> label.gii (fsaverage)       via Connectome Workbench
#      -label-resample, using the HCP deformation spheres (fs_LR-deformed_to-fsaverage)
#      and the source no-medial-wall ROI (-current-roi).
#   3. mask the fsaverage medial wall in the resampled labels   via wb_command -metric-mask
#      with the fsaverage no-medial-wall ROI.
#   4. masked keys + LabelTable -> annot (fsaverage)            via R (convert_labelgii_to_annot.R)
#
# IMPORTANT: the naive fs_LR 32k sphere (`fs_LR.32k.L.sphere.surf.gii`) is NOT in the
# same spherical coordinate system as the FreeSurfer `sphere.reg`, so resampling between
# them directly scrambles the anatomy (medial wall lands in the prefrontal cortex).
# The correct approach (used here, and by the 'neuromaps' package) is to resample with
# both spheres in the SAME (fsaverage) space, using the HCP 'fs_LR-deformed_to-fsaverage'
# spheres in template_subject_meshes/registration/, then mask the target medial wall.
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

# ---- derived paths -------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ATLAS_SRC="$REPO_ROOT/atlas_fs_LR_32"     # source atlases (fs_LR 32k annots)
ATLAS_OUT="$REPO_ROOT/atlas_fsaverage"    # output atlases (fsaverage annots)
MESH_DIR="$REPO_ROOT/template_subject_meshes"
REG_DIR="$MESH_DIR/registration"          # HCP deformation spheres, area metrics, ROIs
WORK="$(mktemp -d -t fslr2fsavg.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

MRIS_CONVERT="$FREESURFER_HOME/bin/mris_convert"
ATLASES=(aal3 aparc brainnetome schaefer100 schaefer200 schaefer300 schaefer400 schaefer1000)

mkdir -p "$ATLAS_OUT"

for ATLAS in "${ATLASES[@]}"; do
  for HEMI in L R; do
    HEMI_LR=$([ "$HEMI" = "L" ] && echo lh || echo rh)

    # 1. annot (fs_LR 32k) -> label.gii (fs_LR 32k)
    "$MRIS_CONVERT" --annot "$ATLAS_SRC/${HEMI_LR}.${ATLAS}.annot" \
      "$MESH_DIR/fs_LR_32/fs_LR.32k.${HEMI}.midthickness.surf.gii" \
      "$WORK/${HEMI_LR}.${ATLAS}.label.gii"

    # 2. resample labels fs_LR 32k -> fsaverage (correct HCP deformation spheres)
    "$WB_COMMAND" -label-resample "$WORK/${HEMI_LR}.${ATLAS}.label.gii" \
      "$REG_DIR/fs_LR-deformed_to-fsaverage.${HEMI}.sphere.32k_fs_LR.surf.gii" \
      "$REG_DIR/fsaverage_std_sphere.${HEMI}.164k_fsavg_${HEMI}.surf.gii" \
      ADAP_BARY_AREA "$WORK/${HEMI_LR}.${ATLAS}.fsaverage.label.gii" \
      -area-metrics "$REG_DIR/fs_LR.32k.${HEMI}.vaavg_midthickness.shape.gii" \
                    "$REG_DIR/fsaverage.164k.${HEMI}.vaavg_midthickness.shape.gii" \
      -current-roi "$REG_DIR/fs_LR.32k.${HEMI}.nomedialwall.label.gii"

    # 3. mask the fsaverage medial wall in the resampled labels (writes a metric of keys)
    "$WB_COMMAND" -metric-mask "$WORK/${HEMI_LR}.${ATLAS}.fsaverage.label.gii" \
      "$REG_DIR/fsaverage.164k.${HEMI}.nomedialwall.label.gii" \
      "$WORK/${HEMI_LR}.${ATLAS}.fsaverage.masked.func.gii"

    # 4. masked keys + LabelTable (from the resampled label file) -> annot (fsaverage)
    Rscript "$SCRIPT_DIR/convert_labelgii_to_annot.R" \
      "$WORK/${HEMI_LR}.${ATLAS}.fsaverage.masked.func.gii" \
      "$WORK/${HEMI_LR}.${ATLAS}.fsaverage.label.gii" \
      "$ATLAS_OUT/${HEMI_LR}.${ATLAS}.annot"
  done
done

echo "DONE. fsaverage annots written to $ATLAS_OUT"
