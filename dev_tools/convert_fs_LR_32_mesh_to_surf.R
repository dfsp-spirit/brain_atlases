#!/usr/bin/env Rscript
#
# convert_fs_LR_32_mesh_to_surf.R
# ===============================
#
# Convert the fs_LR 32k (conte69 / DiedrichsenLab) template meshes from GIFTI
# surface format (*.surf.gii) to native FreeSurfer surface format (the binary
# "tris" surface format, i.e. *.surf without subject name).
#
# Output files follow the FreeSurfer per-hemisphere naming convention
#   <hemi>.<surf_type>          (no subject name, no .surf extension)
# e.g.
#   fs_LR.32k.L.pial.surf.gii   ->  lh.pial
#   fs_LR.32k.R.sphere.surf.gii ->  rh.sphere
#
# The conversion is a pure format translation: the surface geometry (vertex
# coordinates and faces) is copied 1:1. Because the GIFTI data is float32 and
# the FreeSurfer surface format is also written as float32, the round trip is
# lossless up to the float32 precision of the source data.
#
# Requirements:
#   - R with the 'freesurferformats' package (read.fs.surface / write.fs.surface).
#
# Usage (call from the repository root):
#   Rscript dev_tools/convert_fs_LR_32_mesh_to_surf.R [outdir]
#
# The optional outdir overrides the default output directory. The script
# resolves the repository root from its own location, so it also works when
# called from any directory inside the repo.

# ---------------------------------------------------------------------------
# 0. Configuration
# ---------------------------------------------------------------------------
MESH_SUBDIR <- file.path("template_subject_meshes", "fs_LR_32");            # input meshes, relative to repo root
OUT_SUBDIR <- file.path(MESH_SUBDIR, "converted_to_freesurfer_surf_format"); # output surfaces, relative to repo root
COORD_TOLERANCE <- 1e-3;   # absolute max coordinate difference accepted in the read-back check

# ---------------------------------------------------------------------------
# 1. Locate repo root and input/output directories
# ---------------------------------------------------------------------------
args_all <- commandArgs(trailingOnly = FALSE);
args <- commandArgs(trailingOnly = TRUE);
file_arg <- sub("^--file=", "", args_all[grepl("^--file=", args_all)]);
script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg)) else getwd();
repo_root <- dirname(script_dir);   # dev_tools/ is directly under the repo root

mesh_dir <- file.path(repo_root, MESH_SUBDIR);
outdir <- if (length(args) >= 1L && nzchar(args[1])) {
  # An explicit output dir is treated as relative to the repo root for
  # consistency with the default, but absolute paths are used as-is.
  if (grepl("^(/|[A-Za-z]:[/\\\\])", args[1])) args[1] else file.path(repo_root, args[1])
} else {
  file.path(repo_root, OUT_SUBDIR)
};
if (!dir.exists(mesh_dir)) {
  stop(sprintf("Input mesh directory not found: %s", mesh_dir));
}
dir.create(outdir, showWarnings = FALSE, recursive = TRUE);

cat(sprintf("Repo root : %s\n", repo_root));
cat(sprintf("Input dir : %s\n", mesh_dir));
cat(sprintf("Output dir: %s\n", outdir));

# ---------------------------------------------------------------------------
# 2. Check the required R package
# ---------------------------------------------------------------------------
if (!requireNamespace("freesurferformats", quietly = TRUE)) {
  stop('R package "freesurferformats" is required. Install it with: install.packages("freesurferformats")');
}
suppressMessages(library(freesurferformats));
cat(sprintf("Using freesurferformats %s\n\n", as.character(packageVersion("freesurferformats"))));

# ---------------------------------------------------------------------------
# 3. Collect the fs_LR 32k mesh files
# ---------------------------------------------------------------------------
# Filenames look like 'fs_LR.32k.L.pial.surf.gii'. Extract hemisphere and
# surface type; a FreeSurfer surface file is '<hemi>.<surf_type>' (no subject).
mesh_re <- "^fs_LR\\.32k\\.([LR])\\.(.+)\\.surf\\.gii$";
hemi_to_fs <- c("L" = "lh", "R" = "rh");

all_files <- list.files(mesh_dir, pattern = "\\.surf\\.gii$", full.names = FALSE);
if (length(all_files) == 0L) {
  stop(sprintf("No *.surf.gii mesh files found in %s", mesh_dir));
}
matched <- grepl(mesh_re, all_files);
if (any(!matched)) {
  warning(sprintf("Ignoring %d file(s) that do not match the expected naming 'fs_LR.32k.<L|R>.<type>.surf.gii':\n  %s",
                  sum(!matched), paste(all_files[!matched], collapse = "\n  ")));
}
mesh_files <- all_files[matched];

# ---------------------------------------------------------------------------
# 4. Convert each mesh
# ---------------------------------------------------------------------------
convert_one <- function(src_name) {
  m <- regexec(mesh_re, src_name);
  parts <- regmatches(src_name, m)[[1]];
  hemi_code <- parts[2];
  surf_type <- parts[3];

  in_path <- file.path(mesh_dir, src_name);
  out_name <- sprintf("%s.%s", hemi_to_fs[[hemi_code]], surf_type);
  out_path <- file.path(outdir, out_name);

  surf <- read.fs.surface(in_path);   # format = "auto": detects GIFTI (fs.surface with $vertices + $faces)
  n_verts <- nrow(surf$vertices);
  n_faces <- nrow(surf$faces);
  if (n_verts == 0L || n_faces == 0L) {
    stop(sprintf("Read surface with no geometry from %s (verts=%d, faces=%d)", in_path, n_verts, n_faces));
  }

  write.fs.surface(out_path, surf$vertices, surf$faces, format = "auto");

  # Read-back check: geometry must round-trip losslessly (both sides float32).
  check <- read.fs.surface(out_path);
  max_diff <- max(abs(check$vertices - surf$vertices));
  if (nrow(check$vertices) != n_verts || nrow(check$faces) != n_faces) {
    stop(sprintf("Read-back mismatch for %s: verts %d -> %d, faces %d -> %d",
                 out_path, n_verts, nrow(check$vertices), n_faces, nrow(check$faces)));
  }
  if (max_diff > COORD_TOLERANCE) {
    warning(sprintf("Read-back of %s differs from source by up to %.6g (tolerance %.1g); please check.",
                    out_path, max_diff, COORD_TOLERANCE));
  }

  cat(sprintf("  %-34s -> %-12s (%d verts, %d faces, max coord diff %.2e)\n",
              src_name, out_name, n_verts, n_faces, max_diff));
  return(invisible(list(in_path = in_path, out_path = out_path, n_verts = n_verts, n_faces = n_faces)));
}

cat(sprintf("Converting %d fs_LR 32k meshes to FreeSurfer surface format...\n", length(mesh_files)));
results <- lapply(sort(mesh_files), convert_one);
cat(sprintf("\nDone. Wrote %d FreeSurfer surface files to: %s\n", length(results), outdir));

# ---------------------------------------------------------------------------
# 5. Write the cortex labels (lh.cortex.label / rh.cortex.label)
# ---------------------------------------------------------------------------
# A FreeSurfer subject usually ships a per-hemisphere cortex label that lists the
# cortex (non-medial-wall) vertices. fsaverage ships one
# (template_subject_meshes/fsaverage/lh.cortex.label); we derive the same for the
# fs_LR 32k mesh from the HCP no-medial-wall ROI in
# template_subject_meshes/registration/ (value 1 = cortex, 0 = medial wall).
# The coordinates written into the label are placeholders: FreeSurfer tools use the
# vertex indices, not the coordinates, of a cortex label.
if (!requireNamespace("gifti", quietly = TRUE)) {
  stop('R package "gifti" is required to write the cortex labels. Install it with: install.packages("gifti", dependencies=TRUE)');
}
suppressMessages(library(gifti));

REG_DIR <- file.path(repo_root, "template_subject_meshes", "registration");
cortex_re <- "^fs_LR\\.32k\\.([LR])\\.nomedialwall\\.label\\.gii$";
roi_files <- list.files(REG_DIR, pattern = cortex_re, full.names = TRUE);
if (length(roi_files) == 0L) {
  warning(sprintf("No no-medial-wall ROI files found in %s; skipping cortex label generation.", REG_DIR));
} else {
  cat("Writing fs_LR 32k cortex labels...\n");
  for (roi_path in sort(roi_files)) {
    roi_name <- basename(roi_path);
    m <- regexec(cortex_re, roi_name);
    parts <- regmatches(roi_name, m)[[1]];
    hemi_code <- parts[2];
    hemi_fs <- hemi_to_fs[[hemi_code]];

    roi <- gifti::read_gifti(roi_path)$data[[1]];
    cortex_verts <- which(as.integer(roi) == 1L);   # 1-based vertex indices
    if (length(cortex_verts) == 0L || length(cortex_verts) >= length(roi)) {
      stop(sprintf("Unexpected cortex vertex count (%d of %d) in ROI %s",
                   length(cortex_verts), length(roi), roi_path));
    }

    cortex_label_path <- file.path(outdir, sprintf("%s.cortex.label", hemi_fs));
    freesurferformats::write.fs.label(cortex_label_path, vertex_indices = cortex_verts,
                                      indices_are_one_based = TRUE);

    # Read-back check: the label must contain exactly the cortex vertex indices.
    check <- freesurferformats::read.fs.label(cortex_label_path);   # 0-based as stored
    if (length(check) != length(cortex_verts)) {
      stop(sprintf("Read-back mismatch for cortex label %s: wrote %d vertices, read %d",
                   cortex_label_path, length(cortex_verts), length(check)));
    }
    cat(sprintf("  wrote cortex label %s (%d vertices)\n", cortex_label_path, length(cortex_verts)));
  }
}
