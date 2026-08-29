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
#     '02_annot_medial_views' example in fsbrain/examples/rgl_vs_scimesh). If the
#     fsaverage subjects_dir layout is missing, the rearrange script
#     (atlas_fsaverage/subjects_dir/rearrange_into_subjects_dir.sh) is run first
#     to materialize surf/ and label/.
#   * fs_LR 32k atlases (atlas_fs_LR_32/) are NOT in that layout, so the meshes
#     and annotations are loaded by file and the coloredmeshes are built from
#     the preloaded data.
#
# Package versions are pinned for reproducibility: fsbrain 0.7.0 and scimesh
# 0.3.4 are installed from CRAN if a different version is present (this is
# intentional, so output is reproducible across machines).
#
# Usage:
#   Rscript dev_tools/visualize_all.R [outdir]
#   (outdir defaults to the current working directory)

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
outdir <- if (length(args) >= 1L && nzchar(args[1])) args[1] else getwd();
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

render_to_png <- function(coloredmeshes, outfile, view_angles = c("sd_medial_lh", "sd_medial_rh"),
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
fsaverage_subjects_dir <- file.path(repo_root, "atlas_fsaverage", "subjects_dir");
fsaverage_subject <- "fsaverage";
probe_file <- file.path(fsaverage_subjects_dir, fsaverage_subject, "surf", "lh.white");

if (!file.exists(probe_file)) {
  cat("  fsaverage subjects_dir layout missing; running rearrange_into_subjects_dir.sh ...\n");
  rearrange_script <- file.path(fsaverage_subjects_dir, "rearrange_into_subjects_dir.sh");
  if (!file.exists(rearrange_script)) {
    stop(sprintf("Rearrange script not found: %s", rearrange_script));
  }
  status <- system2("bash", c(rearrange_script));
  if (status != 0L) stop("rearrange_into_subjects_dir.sh failed.");
} else {
  cat("  fsaverage subjects_dir layout present.\n");
}

fsaverage_atlases <- c("HCPMMP1", "aparc", "aal3", "brainnetome",
                       "schaefer100", "schaefer200", "schaefer300", "schaefer400", "schaefer1000");
for (atlas in fsaverage_atlases) {
  cat(sprintf("  rendering fsaverage/%s ...\n", atlas));
  cm <- fsbrain::vis.subject.annot(fsaverage_subjects_dir, fsaverage_subject, atlas, views = NULL);
  render_to_png(cm, file.path(outdir, sprintf("fsaverage_%s.png", atlas)));
}

# ---------------------------------------------------------------------------
# 4. fs_LR 32k atlases (loaded by file, not in subjects_dir layout)
# ---------------------------------------------------------------------------
cat("\n== fs_LR 32k atlases ==\n");
mesh_dir <- file.path(repo_root, "template_subject_meshes", "fs_LR_32");
atlas_dir <- file.path(repo_root, "atlas_fs_LR_32");
fslr_atlases <- c("aparc", "aal3", "brainnetome",
                  "schaefer100", "schaefer200", "schaefer300", "schaefer400", "schaefer1000");
surface_name <- "inflated";   # visualize the parcellations on the inflated mesh

for (atlas in fslr_atlases) {
  cat(sprintf("  rendering fs_LR 32k/%s ...\n", atlas));
  lh_surf <- freesurferformats::read.fs.surface(file.path(mesh_dir, sprintf("fs_LR.32k.L.%s.surf.gii", surface_name)));
  rh_surf <- freesurferformats::read.fs.surface(file.path(mesh_dir, sprintf("fs_LR.32k.R.%s.surf.gii", surface_name)));
  lh_annot <- freesurferformats::read.fs.annot(file.path(atlas_dir, sprintf("lh.%s.annot", atlas)));
  rh_annot <- freesurferformats::read.fs.annot(file.path(atlas_dir, sprintf("rh.%s.annot", atlas)));
  cm_lh <- fsbrain::coloredmesh.from.preloaded.data(lh_surf, col = lh_annot$hex_colors_rgb, hemi = "lh");
  cm_rh <- fsbrain::coloredmesh.from.preloaded.data(rh_surf, col = rh_annot$hex_colors_rgb, hemi = "rh");
  # Categorical atlas colors: no data range, so no colorbar.
  render_to_png(list("lh" = cm_lh, "rh" = cm_rh), file.path(outdir, sprintf("fsLR32_%s.png", atlas)),
                draw_colorbar = FALSE);
}

cat(sprintf("\nDone. Images written to: %s\n", outdir));
