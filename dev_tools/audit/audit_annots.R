#!/usr/bin/env Rscript
# audit_annots.R
#
# Full audit of all .annot atlases in this repo.
#
# For every atlas it writes a per-region CSV table (one row per colortable entry)
# with, per region: vertex count on the mesh, color code, usage flags, and - for
# atlases that WE converted (the fsaverage versions, except HCP-MMP1 which we only
# redistribute) - the corresponding vertex count on the SOURCE mesh and the source
# mesh name.
#
# Atlases are discovered from the repo layout (lh.<atlas>.annot in each space dir);
# the per-atlas provenance.json files provide the expected vertex counts, the
# derived/downloaded flag and the source files used for the source-mesh columns.
#
# Outputs (in dev_tools/audit/output/):
#   * atlas_fsaverage/<atlas>.csv  and  atlas_fs_LR_32/<atlas>.csv  (per-region tables)
#   * atlas_summary.csv        (one row per atlas + hemisphere)
#   * audit_annots_output.txt  (human-readable version of the summary)
#
# Usage: Rscript dev_tools/audit/audit_annots.R [repo_root]
# Requires R packages: freesurferformats, jsonlite.

suppressPackageStartupMessages({
  library(freesurferformats)
  library(jsonlite)
})

# ---- helpers -------------------------------------------------------------------
get_repo_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", args[grepl("^--file=", args)])
  if (length(f) && nzchar(f) && file.exists(f)) {
    return(normalizePath(file.path(dirname(f), "..", "..")))
  }
  normalizePath(".")
}

# Strip hemisphere markers from a region name (same rules as in
# convert_labelgii_to_annot.R): L_/R_/LH_/RH_ prefix, _L/_R/_LH/_RH suffix, _LH_/_RH_ infix.
norm_name <- function(nm) {
  nm <- sub('^[LR]H?_', '', nm)
  nm <- sub('_[LR]H?$', '', nm)
  nm <- sub('_[LR]H?_', '_', nm)
  nm
}

# Per-region table for one annot file (one row per colortable entry). Returns a list
# with $df (the table), $n_total (vertices on the mesh) and $n_ctab_rows.
#
# Notes:
#  * n_vertices counts mesh vertices per COLOR CODE. Some annots (notably the fs_LR 32k
#    ones) carry the full bilateral colortable whose left/right regions share colors, so
#    the same count is reported for aliased regions -> use the duplicate_code column to
#    filter down to distinct regions.
#  * vertices whose code is absent from the colortable (e.g. the HCP-MMP1 medial wall,
#    code 16777215) are added as synthetic 'not in colortable' rows, so the CSV row sum
#    always equals the mesh vertex count.
annot_region_table <- function(annot_path, atlas, space, hemi) {
  a <- read.fs.annot(annot_path)
  ct <- a$colortable_df
  label_codes <- a$label_codes
  n_total <- length(label_codes)
  counts <- table(label_codes)
  codes <- ct$code
  idx <- ct$struct_index
  nms <- ct$struct_name
  is_unknown <- tolower(trimws(nms)) %in% c("unknown", "medial wall", "") |
                (idx == 0L & tolower(trimws(nms)) == "")
  n_vert <- as.integer(counts[as.character(codes)])
  n_vert[is.na(n_vert)] <- 0L
  dup_code <- duplicated(codes) | duplicated(codes, fromLast = TRUE)

  df <- data.frame(
    atlas = atlas, space = space, hemisphere = hemi,
    region_index = idx, region_name = nms,
    color_r = ct$r, color_g = ct$g, color_b = ct$b, color_alpha = ct$a,
    color_code = codes, n_vertices = n_vert,
    used = n_vert > 0L, is_unknown = is_unknown, duplicate_code = dup_code,
    stringsAsFactors = FALSE
  )

  # synthetic rows for codes present on the mesh but absent from the colortable
  unattributed <- setdiff(unique(label_codes), codes)
  for (uc in unattributed) {
    df <- rbind(df, data.frame(
      atlas = atlas, space = space, hemisphere = hemi,
      region_index = NA_integer_, region_name = sprintf("code %d (not in colortable)", uc),
      color_r = NA_integer_, color_g = NA_integer_, color_b = NA_integer_, color_alpha = NA_integer_,
      color_code = uc, n_vertices = as.integer(counts[as.character(uc)]),
      used = TRUE, is_unknown = TRUE, duplicate_code = FALSE,
      stringsAsFactors = FALSE
    ))
  }
  list(df = df, n_total = n_total, n_ctab_rows = nrow(ct))
}

# Add source-mesh columns for a derived (converted) atlas. Source regions are joined
# to target regions by normalized region name.
add_source_columns <- function(df, prov, hemi, repo) {
  src_files <- unlist(prov$source_files)
  src_file <- src_files[grepl(sprintf("^.*/%s\\.", if (hemi == "lh") "lh" else "rh"), src_files)]
  if (length(src_file) != 1L) {
    warning(sprintf("cannot locate source file for %s %s", prov$atlas, hemi))
    df$source_region_name <- NA_character_
    df$source_n_vertices <- NA_integer_
    df$source_mesh <- if (!is.null(prov$origin_mesh)) prov$origin_mesh else NA_character_
    return(df)
  }
  s <- read.fs.annot(file.path(repo, src_file))
  sct <- s$colortable_df
  scounts <- table(s$label_codes)
  snorm <- norm_name(sct$struct_name)
  sn_vert <- as.integer(scounts[as.character(sct$code)])
  sn_vert[is.na(sn_vert)] <- 0L
  # keep only source regions actually used on the source mesh (ipsilateral labels),
  # so the name join is unambiguous even for atlases with shared color codes.
  used_src <- sn_vert > 0L
  m <- match(df$region_name, snorm[used_src])
  df$source_region_name <- sct$struct_name[used_src][m]
  df$source_n_vertices <- sn_vert[used_src][m]
  df$source_mesh <- if (!is.null(prov$origin_mesh)) prov$origin_mesh else NA_character_
  df
}

# ---- main -----------------------------------------------------------------------
args <- commandArgs(TRUE)
repo <- if (length(args) >= 1L) normalizePath(args[1L]) else get_repo_root()
out_dir <- file.path(get_repo_root(), "dev_tools", "audit", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

spaces <- c("atlas_fsaverage", "atlas_fs_LR_32")

summary_rows <- list()
any_fail <- FALSE

for (sp in spaces) {
  sp_dir <- file.path(repo, sp)
  annots <- list.files(sp_dir, pattern = "^lh\\..*\\.annot$", full.names = FALSE)
  atlases <- sub("^lh\\.(.*)\\.annot$", "\\1", annots)
  sp_out <- file.path(out_dir, sp)
  dir.create(sp_out, showWarnings = FALSE, recursive = TRUE)

  for (atlas in atlases) {
    prov_path <- file.path(repo, sp, sprintf("%s.provenance.json", atlas))
    prov <- NULL
    if (file.exists(prov_path)) {
      prov <- jsonlite::fromJSON(prov_path, simplifyVector = TRUE)
    }
    mesh_n <- if (!is.null(prov)) as.integer(prov$mesh_n_vertices) else NA_integer_
    derived <- if (!is.null(prov)) isTRUE(prov$derived) else FALSE

    hemi_tables <- list()
    for (hemi in c("lh", "rh")) {
      f <- file.path(sp_dir, sprintf("%s.%s.annot", hemi, atlas))
      if (!file.exists(f)) next
      tbl <- annot_region_table(f, atlas, sp, hemi)
      df <- tbl$df
      if (derived) df <- add_source_columns(df, prov, hemi, repo)
      hemi_tables[[hemi]] <- df

      n_regions <- sum(!df$is_unknown)
      n_used <- length(unique(df$color_code[df$used]))  # distinct labels on the mesh
      n_vert <- tbl$n_total                             # actual mesh vertex count
      mesh_ok <- if (is.na(mesh_n)) NA else n_vert == mesh_n
      if (isTRUE(mesh_ok == FALSE)) any_fail <- TRUE
      src_mesh <- if (!is.null(df$source_mesh)) df$source_mesh[1L] else NA_character_
      summary_rows[[length(summary_rows) + 1L]] <- data.frame(
        atlas = atlas, space = sp, hemisphere = hemi,
        ctab_rows = tbl$n_ctab_rows, regions = n_regions, used_labels = n_used,
        vertices = n_vert, expected = mesh_n,
        mesh_ok = if (is.na(mesh_ok)) "n/a" else if (mesh_ok) "ok" else "MISMATCH",
        derived = derived,
        source_mesh = src_mesh,
        stringsAsFactors = FALSE
      )
    }

    combined <- do.call(rbind, hemi_tables)
    csv_path <- file.path(sp_out, sprintf("%s.csv", atlas))
    write.csv(combined, csv_path, row.names = FALSE)
    cat(sprintf("wrote %s (%d rows)\n", csv_path, nrow(combined)))
  }
}

summary_df <- do.call(rbind, summary_rows)
write.csv(summary_df, file.path(out_dir, "atlas_summary.csv"), row.names = FALSE)

# human-readable summary (mirrors the old audit_annots_output.txt)
sink(file.path(out_dir, "audit_annots_output.txt"))
fmt <- "%-12s %-11s %-3s %-9s %-8s %-11s %-8s %-9s %-8s %-8s\n"
cat(sprintf(fmt, "atlas", "space", "hemi", "ctab_rows", "regions", "used_labels",
            "vertices", "expected", "mesh_ok", "derived"))
cat(strrep("-", 92), "\n")
for (i in seq_len(nrow(summary_df))) {
  r <- summary_df[i, ]
  cat(sprintf(fmt, r$atlas, r$space, r$hemisphere, r$ctab_rows, r$regions,
              r$used_labels, r$vertices, r$expected, r$mesh_ok, r$derived))
}
sink()

if (any_fail) {
  stop("AUDIT FAILED: at least one atlas does not match its expected vertex count.")
}
cat(sprintf("DONE. Outputs in %s\n", out_dir))
