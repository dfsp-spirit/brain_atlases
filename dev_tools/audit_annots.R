#!/usr/bin/env Rscript
# audit_annots.R
# Full audit of all .annot atlases in the repo using freesurferformats::read.fs.annot:
#   * region count (colortable rows excluding 'unknown')
#   * distinct labels actually used on the mesh
#   * vertex count, checked against the corresponding template mesh
suppressPackageStartupMessages(library(freesurferformats))

repo <- "/home/ts/develop/brain_atlases"

# expected vertex counts per space (from template meshes)
mesh_n <- list(
  atlas_fsaverage = 163842L,   # 164k fsaverage
  atlas_fs_LR_32  = 32492L     # 32k fs_LR (conte69)
)

atlas_files <- list(
  atlas_fsaverage = c("HCPMMP1", "aparc", "aal3", "brainnetome",
                "schaefer100", "schaefer200", "schaefer300", "schaefer400", "schaefer1000"),
  atlas_fs_LR_32  = c("aparc", "aal3", "brainnetome",
                "schaefer100", "schaefer200", "schaefer300", "schaefer400", "schaefer1000")
)

fmt <- "%-11s %-3s %-10s %-10s %-10s %-9s %-9s\n"
cat(sprintf(fmt, "atlas", "hemi", "ctab_rows", "regions", "used_labels", "vertices", "mesh_ok"))
cat(strrep("-", 68), "\n")

for (sp in names(atlas_files)) {
  for (atlas in atlas_files[[sp]]) {
    for (hemi in c("lh", "rh")) {
      f <- file.path(repo, sp, sprintf("%s.%s.annot", hemi, atlas))
      a <- read.fs.annot(f)
      ct <- a$colortable_df
      is_unknown <- tolower(trimws(ct$struct_name)) %in% c("unknown", "medial wall", "") |
                    (ct$struct_index == 0L & tolower(trimws(ct$struct_name)) == "")
      n_regions <- sum(!is_unknown)
      n_used <- length(unique(a$label_codes))
      n_vert <- length(a$label_codes)
      exp_n <- mesh_n[[sp]]
      ok <- if (n_vert == exp_n) "ok" else sprintf("!= %d", exp_n)
      cat(sprintf(fmt, atlas, hemi, nrow(ct), n_regions, n_used, n_vert, ok))
    }
  }
  cat("\n")
}

# ---------------------------------------------------------------------------
# Sanity check: print a few colortable names so the parse can be eyeballed.
# (Schaefer regions are per-network colored, so counts alone don't show that
# e.g. schaefer1000 really has 500 distinct names per hemisphere.)
# ---------------------------------------------------------------------------
for (v in c("schaefer100", "schaefer1000")) {
  f <- file.path(repo, "atlas_fsaverage", sprintf("lh.%s.annot", v))
  a <- read.fs.annot(f)
  cat(sprintf("[%s lh] first 6 ctab names:\n", v))
  print(head(a$colortable_df$struct_name, 6))
  cat(sprintf("[%s lh] last 3 ctab names:\n", v))
  print(tail(a$colortable_df$struct_name, 3))
}
