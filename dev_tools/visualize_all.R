#!/usr/bin/env Rscript
#
# visualize_all.R
# ===============
#
# Render all atlases in this repository as PNG images using the fsbrain scimesh
# renderer backend (fully headless, no display needed).
#
#   * fsaverage atlases (atlas_fsaverage/) are rendered on the fsaverage template
#     through the standard fsbrain subjects_dir API (medial views, like the
#     '02_annot_medial_views' example in fsbrain/examples/rgl_vs_scimesh). The
#     rearrange script (dev_tools/rearrange_fsaverage_into_subjects_dir.sh)
#     is run unconditionally first so surf/ and label/ in the subjects_dir layout
#     always mirror the current atlas_fsaverage/ annots (stale copies would render
#     outdated labels).
#   * fs_LR 32k atlases are rendered on the fs_LR_32 subject in the same
#     materialized subjects_dir layout (via dev_tools/rearrange_fs_LR_32_into_subjects_dir.sh),
#     using the same fsbrain subjects_dir API as the fsaverage atlases.
#
# Package versions are pinned for reproducibility: fsbrain 0.7.0 and scimesh
# 0.3.4 are installed from CRAN if a different version is present (this is
# intentional, so output is reproducible across machines).
#
# Usage:
#   Rscript dev_tools/visualize_all.R [outdir]
#   (outdir defaults to dev_tools/visualize_all_output)

# ---------------------------------------------------------------------------
# 0. Configuration
# ---------------------------------------------------------------------------
CRAN_REPO <- "https://cloud.r-project.org";
FSBRAIN_VERSION <- "0.7.0";
SCIMESH_VERSION <- "0.3.4";

args_all <- commandArgs(trailingOnly = FALSE);
args <- commandArgs(trailingOnly = TRUE);
file_arg <- sub("^--file=", "", args_all[grepl("^--file=", args_all)]);
script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg)) else getwd();
repo_root <- dirname(script_dir);   # dev_tools/ is directly under the repo root
outdir <- if (length(args) >= 1L && nzchar(args[1])) args[1] else file.path(script_dir, "visualize_all_output");
dir.create(outdir, showWarnings = FALSE, recursive = TRUE);

cat(sprintf("Repo root : %s\n", repo_root));
cat(sprintf("Output dir: %s\n", outdir));

# ---------------------------------------------------------------------------
# 1. Install pinned package versions (idempotent)
# ---------------------------------------------------------------------------
ensure_cran_version <- function(pkg, version) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    v <- as.character(utils::packageVersion(pkg));
    if (v == version) {
      cat(sprintf("  %s %s already installed.\n", pkg, v));
      return(invisible(TRUE));
    }
    cat(sprintf("  %s %s is installed; installing required %s %s.\n", pkg, v, pkg, version));
  }
  if (!requireNamespace("remotes", quietly = TRUE)) {
    utils::install.packages("remotes", repos = CRAN_REPO);
  }
  cat(sprintf("  Installing %s %s from CRAN...\n", pkg, version));
  remotes::install_version(pkg, version = version, repos = CRAN_REPO, upgrade = "never");
  if (!requireNamespace(pkg, quietly = TRUE) || as.character(utils::packageVersion(pkg)) != version) {
    stop(sprintf("Failed to install %s %s.", pkg, version));
  }
  return(invisible(TRUE));
}

cat("== Ensuring package versions ==\n");
ensure_cran_version("fsbrain", FSBRAIN_VERSION);
ensure_cran_version("scimesh", SCIMESH_VERSION);

suppressPackageStartupMessages({ library(fsbrain); });
options(fsbrain.renderer_backend = "scimesh");
if (requireNamespace("scimesh", quietly = TRUE)) {
  options(fsbrain.scimesh.output_dims = c(1000L, 1000L));
}

# ---------------------------------------------------------------------------
# 2. Rendering helpers
# ---------------------------------------------------------------------------
close_rgl_windows <- function() {
  if (requireNamespace("rgl", quietly = TRUE)) {
    while (rgl::cur3d() > 0L) rgl::close3d();
  }
}

render_to_png <- function(coloredmeshes, outfile,
                          view_angles = c("sd_lateral_lh", "sd_lateral_rh", "sd_medial_lh", "sd_medial_rh"),
                          draw_colorbar = TRUE) {
  fsbrain::export(coloredmeshes, output_img = outfile, silent = TRUE, view_angles = view_angles,
                  draw_colorbar = draw_colorbar);
  close_rgl_windows();
  cat("  wrote:", outfile, "\n");
  return(invisible(outfile));
}

# ---------------------------------------------------------------------------
# 3. fsaverage atlases (standard fsbrain subjects_dir API)
# ---------------------------------------------------------------------------
cat("\n== fsaverage atlases ==\n");
fsaverage_subjects_dir <- file.path(repo_root, "subjects_dir");
fsaverage_subject <- "fsaverage";

# Always re-materialize surf/ and label/ from the current atlas_fsaverage/ annots.
# Running the rearrange script unconditionally guarantees the render matches the
# latest annots (previously it only ran when the layout was missing, which left
# stale copies of outdated annots in subjects_dir/fsaverage/label/).
rearrange_script <- file.path(repo_root, "dev_tools", "rearrange_fsaverage_into_subjects_dir.sh");
if (!file.exists(rearrange_script)) {
  stop(sprintf("Rearrange script not found: %s", rearrange_script));
}
cat("  Refreshing fsaverage subjects_dir layout (rearrange_into_subjects_dir.sh) ...\n");
status <- system2("bash", c(rearrange_script));
if (status != 0L) stop("rearrange_into_subjects_dir.sh failed.");

fsaverage_atlases <- c("HCPMMP1", "aparc_conv", "aal3", "brainnetome",
                       "schaefer100", "schaefer200", "schaefer300", "schaefer400", "schaefer1000");
for (atlas in fsaverage_atlases) {
  cat(sprintf("  rendering fsaverage/%s ...\n", atlas));
  cm <- fsbrain::vis.subject.annot(fsaverage_subjects_dir, fsaverage_subject, atlas, views = NULL);
  render_to_png(cm, file.path(outdir, sprintf("fsaverage_%s.png", atlas)));
}

# ---------------------------------------------------------------------------
# 4. fs_LR 32k atlases (standard fsbrain subjects_dir API, materialized layout)
# ---------------------------------------------------------------------------
cat("\n== fs_LR 32k atlases ==\n");
fslr_subjects_dir <- file.path(repo_root, "subjects_dir");
fslr_subject <- "fs_LR_32";

# Always re-materialize surf/ and label/ from the current sources (converted
# meshes + atlas_fs_LR_32/ annots), mirroring section 3 for fsaverage.
fslr_rearrange_script <- file.path(repo_root, "dev_tools", "rearrange_fs_LR_32_into_subjects_dir.sh");
if (!file.exists(fslr_rearrange_script)) {
  stop(sprintf("Rearrange script not found: %s", fslr_rearrange_script));
}
cat("  Refreshing fs_LR 32k subjects_dir layout (rearrange_fs_LR_32_into_subjects_dir.sh) ...\n");
status <- system2("bash", c(fslr_rearrange_script));
if (status != 0L) stop("rearrange_fs_LR_32_into_subjects_dir.sh failed.");

fslr_atlases <- c("aparc_conv", "aal3", "brainnetome",
                  "schaefer100", "schaefer200", "schaefer300", "schaefer400", "schaefer1000");
surface_name <- "inflated";   # visualize the parcellations on the inflated mesh

for (atlas in fslr_atlases) {
  cat(sprintf("  rendering fs_LR 32k/%s ...\n", atlas));
  cm <- fsbrain::vis.subject.annot(fslr_subjects_dir, fslr_subject, atlas, surface = surface_name, views = NULL);
  # Categorical atlas colors: no data range, so no colorbar.
  render_to_png(cm, file.path(outdir, sprintf("fsLR32_%s.png", atlas)),
                draw_colorbar = FALSE);
}


cat(sprintf("\nDone. Images written to: %s\n", outdir));
