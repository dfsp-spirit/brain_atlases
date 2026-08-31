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
# For every converted atlas it also writes machine-readable metadata next to the
# annots:
#   * an attribution.json (authors, license, citation; derived from the source fs_LR 32k
#     attribution, with the space fields adjusted for the fsaverage mesh), and
#   * a provenance.json (source files, tool versions, sha256 checksums) that records
#     where the atlas came from and how it was produced.

set -euo pipefail

# ---- settings (edit once) ------------------------------------------------------
WB_COMMAND="$HOME/software/connectome_workbench/workbench/bin_linux64/wb_command"
FREESURFER_HOME="${FREESURFER_HOME:-/home/ts/software/freesurfer/freesurfer7.4.1}"

# ---- provenance generation -----------------------------------------------------
# Best-effort tool version detection (recorded in the provenance.json files).
detect_wb_version() {
  "$WB_COMMAND" -version 2>&1 | sed -n 's/^Version: //p' | head -1 || true
}
detect_fs_version() {
  if [ -f "$FREESURFER_HOME/build-stamp.txt" ]; then
    grep -o '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' "$FREESURFER_HOME/build-stamp.txt" | head -1 || true
  fi
}
detect_ff_version() {
  Rscript -e 'cat(as.character(packageVersion("freesurferformats")))' 2>/dev/null || true
}

# Write the provenance.json for one converted atlas (all paths relative to repo root).
# Requires both hemispheres of <atlas> to have been written to ATLAS_OUT already.
write_converted_provenance() {
  local atlas="$1"
  local prov="$ATLAS_OUT/$atlas.provenance.json"
  local wb_ver fs_ver ff_ver
  wb_ver="$(detect_wb_version)"
  fs_ver="$(detect_fs_version)"
  ff_ver="$(detect_ff_version)"

  local sh_src_lh sh_src_rh sh_out_lh sh_out_rh
  sh_src_lh="$(sha256sum "$ATLAS_SRC/lh.$atlas.annot" | cut -d' ' -f1)"
  sh_src_rh="$(sha256sum "$ATLAS_SRC/rh.$atlas.annot" | cut -d' ' -f1)"
  sh_out_lh="$(sha256sum "$ATLAS_OUT/lh.$atlas.annot" | cut -d' ' -f1)"
  sh_out_rh="$(sha256sum "$ATLAS_OUT/rh.$atlas.annot" | cut -d' ' -f1)"

  cat > "$prov" <<EOF
{
  "atlas": "$atlas",
  "space": "fsaverage",
  "mesh": "fsaverage",
  "mesh_n_vertices": 163842,
  "derived": true,
  "origin_space": "atlas_fs_LR_32",
  "origin_mesh": "fs_LR_32",
  "origin_mesh_n_vertices": 32492,
  "source_files": [
    "atlas_fs_LR_32/lh.$atlas.annot",
    "atlas_fs_LR_32/rh.$atlas.annot"
  ],
  "output_files": [
    "atlas_fsaverage/lh.$atlas.annot",
    "atlas_fsaverage/rh.$atlas.annot"
  ],
  "attribution_file": "atlas_fsaverage/$atlas.attribution.json",
  "method": "HCP fs_LR-deformed_to-fsaverage label-resample (ADAP_BARY_AREA) + medial-wall masking",
  "tools": {
    "wb_command": "$wb_ver",
    "FreeSurfer": "$fs_ver",
    "freesurferformats": "$ff_ver"
  },
  "checksums": {
    "atlas_fs_LR_32/lh.$atlas.annot": "sha256:$sh_src_lh",
    "atlas_fs_LR_32/rh.$atlas.annot": "sha256:$sh_src_rh",
    "atlas_fsaverage/lh.$atlas.annot": "sha256:$sh_out_lh",
    "atlas_fsaverage/rh.$atlas.annot": "sha256:$sh_out_rh"
  },
  "generated_at": "$(date +%Y-%m-%d)"
}
EOF
  echo "wrote $prov"
}

# Write the attribution.json for one converted atlas (all paths relative to repo root).
# The resampling does not change the atlas content, so authorship, license, citation and
# source_url are carried over verbatim from the source fs_LR 32k attribution. Only the
# space-related fields change (origin_space, the mesh mention in the title) and a notes
# entry is added that points to the provenance record for the conversion.
write_converted_attribution() {
  local atlas="$1"
  local src="$ATLAS_SRC/$atlas.attribution.json"
  local out="$ATLAS_OUT/$atlas.attribution.json"

  python3 - "$src" "$out" "$atlas" <<'PYEOF'
import json, sys

# Render with 2-space indent, but keep short arrays (e.g. single-element "dois")
# inline, matching the style of the existing attribution.json files in this repo.
def render(obj, level=0):
    pad = " " * (level * 2)
    if isinstance(obj, dict):
        if not obj:
            return "{}"
        items = ["%s  %s: %s" % (pad, json.dumps(k), render(v, level + 1)) for k, v in obj.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(obj, list):
        if not obj:
            return "[]"
        rendered = [render(v, level + 1) for v in obj]
        if len(rendered) == 1 and "\n" not in rendered[0]:
            return "[" + rendered[0] + "]"
        inner = ",\n".join("%s  %s" % (pad, r) for r in rendered)
        return "[\n" + inner + "\n" + pad + "]"
    return json.dumps(obj)

src_path, out_path, atlas = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src_path, "r") as fh:
    att = json.load(fh)
att["origin_space"] = "fsaverage"
att["title"] = att.get("title", "").replace("on conte69/fs_LR 32k mesh", "on fsaverage mesh")
att["notes"] = (
    "Derived: resampled to the FreeSurfer fsaverage mesh (163,842 vertices/hemisphere) "
    "from the fs_LR 32k version; see atlas_fsaverage/%s.provenance.json. Original "
    "attribution of the source atlas applies." % atlas
)
with open(out_path, "w") as fh:
    fh.write(render(att))
    fh.write("\n")
PYEOF
  echo "wrote $out"
}

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
ATLASES=(aal3 aparc_conv brainnetome schaefer100 schaefer200 schaefer300 schaefer400 schaefer1000)

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

  # 5. write the machine-readable provenance and attribution records for this atlas
  write_converted_provenance "$ATLAS"
  write_converted_attribution "$ATLAS"
done

echo "DONE. fsaverage annots written to $ATLAS_OUT"
