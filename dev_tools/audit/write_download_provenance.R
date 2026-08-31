#!/usr/bin/env Rscript
# write_download_provenance.R
#
# Generate provenance.json for atlas / mesh origins in this repo that were
# DOWNLOADED (not produced by the fs_LR 32k -> fsaverage conversion pipeline in
# dev_tools/convert_fsLR32_to_fsaverage.sh). The conversion script writes the
# provenance for the converted (derived) atlases itself; this script covers the
# remaining origins, which are downloaded as-is:
#
#   * the 8 conte69/fs_LR 32k atlases in atlas_fs_LR_32/  (downloaded from OSF)
#   * the HCP-MMP1 atlas on fsaverage in atlas_fsaverage/ (figshare, Mills)
#   * the template meshes in template_subject_meshes/    (fs_LR_32, fsaverage)
#   * the registration data in template_subject_meshes/registration/ (neuromaps/HCP)
#
# For each origin it writes <space>/<atlas>.provenance.json containing:
#   * derived=false, origin="download"
#   * mesh name + vertex count (per-space lookup)
#   * source_url / acquired_at / source_doi (read from the matching
#     <atlas>.attribution.json, or from the .txt for origins that have no
#     attribution.json yet, e.g. registration/)
#   * attribution_file (path to the attribution.json or .txt)
#   * sha256 checksums of every file in the origin directory
#   * generated_at date
#
# Run once and commit the outputs (they are static records):
#   Rscript dev_tools/audit/write_download_provenance.R [repo_root]
#
# Requires R packages: jsonlite, digest.

suppressPackageStartupMessages({
  library(jsonlite)
  library(digest)
})

args <- commandArgs(TRUE)
repo <- if (length(args) >= 1L) normalizePath(args[1L]) else getwd()

# per-space mesh name + vertex count (these are the template constants, verified by
# dev_tools/audit_annots.R). registration/ is mixed (both meshes), so it is absent.
mesh_info <- list(
  "atlas_fs_LR_32" = list(mesh = "fs_LR_32", mesh_n_vertices = 32492L),
  "atlas_fsaverage" = list(mesh = "fsaverage", mesh_n_vertices = 163842L),
  "template_subject_meshes/fs_LR_32" = list(mesh = "fs_LR_32", mesh_n_vertices = 32492L),
  "template_subject_meshes/fsaverage" = list(mesh = "fsaverage", mesh_n_vertices = 163842L)
)

origins <- list(
  # downloaded cortical atlases on conte69/fs_LR 32k (from OSF, via yabplot);
  # files are explicit because atlas_fs_LR_32/ holds all 8 atlases.
  list(atlas = "aparc_conv",   space = "atlas_fs_LR_32", files = c("lh.aparc_conv.annot", "rh.aparc_conv.annot")),
  list(atlas = "aal3",         space = "atlas_fs_LR_32", files = c("lh.aal3.annot", "rh.aal3.annot")),
  list(atlas = "brainnetome",  space = "atlas_fs_LR_32", files = c("lh.brainnetome.annot", "rh.brainnetome.annot")),
  list(atlas = "schaefer100",  space = "atlas_fs_LR_32", files = c("lh.schaefer100.annot", "rh.schaefer100.annot")),
  list(atlas = "schaefer200",  space = "atlas_fs_LR_32", files = c("lh.schaefer200.annot", "rh.schaefer200.annot")),
  list(atlas = "schaefer300",  space = "atlas_fs_LR_32", files = c("lh.schaefer300.annot", "rh.schaefer300.annot")),
  list(atlas = "schaefer400",  space = "atlas_fs_LR_32", files = c("lh.schaefer400.annot", "rh.schaefer400.annot")),
  list(atlas = "schaefer1000", space = "atlas_fs_LR_32", files = c("lh.schaefer1000.annot", "rh.schaefer1000.annot")),
  # downloaded atlas on fsaverage (figshare; Mills projection of Glasser MMP1)
  list(atlas = "HCPMMP1",      space = "atlas_fsaverage", files = c("lh.HCPMMP1.annot", "rh.HCPMMP1.annot")),
  # downloaded template meshes (one origin per dir, so glob)
  list(atlas = "fs_LR_32k",    space = "template_subject_meshes/fs_LR_32"),
  list(atlas = "fsaverage",    space = "template_subject_meshes/fsaverage"),
  # downloaded registration data (HCP deformation spheres/ROIs; has attribution.json)
  list(atlas = "registration", space = "template_subject_meshes/registration")
)

# sha256 of a repo-relative path.
sha256_rel <- function(rel_path, repo) {
  f <- file.path(repo, rel_path)
  if (!file.exists(f)) stop("file does not exist: ", f)
  digest::digest(file = f, algo = "sha256", serialize = FALSE)
}

# Read source_url / acquired_at / source_doi and the attribution_file path for an
# origin: prefer <atlas>.attribution.json, fall back to parsing <atlas>.txt, or use
# an explicit attribution_file given in the origin spec (e.g. registration/).
read_attribution <- function(origin, repo) {
  space <- origin$space
  atlas <- origin$atlas
  if (!is.null(origin$attribution_file)) {
    att_json <- if (grepl("\\.json$", origin$attribution_file)) origin$attribution_file else NULL
    att_txt  <- if (grepl("\\.txt$", origin$attribution_file)) origin$attribution_file else NULL
  } else {
    att_json <- file.path(space, sprintf("%s.attribution.json", atlas))
    att_txt  <- file.path(space, sprintf("%s.txt", atlas))
  }
  out <- list(source_url = NA_character_, acquired_at = NA_character_,
              source_doi = NA_character_, attribution_file = NA_character_)
  if (!is.null(att_json) && file.exists(file.path(repo, att_json))) {
    d <- jsonlite::fromJSON(file.path(repo, att_json))
    out$source_url       <- if (!is.null(d$source_url))      as.character(d$source_url)      else NA_character_
    out$acquired_at      <- if (!is.null(d$acquired_at))     as.character(d$acquired_at)     else NA_character_
    out$source_doi       <- if (!is.null(d$source_doi))      as.character(d$source_doi)      else NA_character_
    out$attribution_file <- att_json
  } else if (!is.null(att_txt) && file.exists(file.path(repo, att_txt))) {
    lines <- readLines(file.path(repo, att_txt), warn = FALSE)
    url <- grep("^\\*\\s*source:", lines, value = TRUE)
    acq <- grep("^\\*\\s*downloaded at:", lines, value = TRUE)
    if (length(url)) out$source_url  <- sub("^\\*\\s*source:\\s*", "", url[1])
    if (length(acq)) out$acquired_at <- sub("^\\*\\s*downloaded at:\\s*", "", acq[1])
    out$attribution_file <- att_txt
  } else {
    stop("no attribution file found for ", atlas, " in ", space)
  }
  out
}

today <- format(Sys.Date(), "%Y-%m-%d")

for (origin in origins) {
  atlas <- origin$atlas
  space <- origin$space
  dir <- file.path(repo, space)
  if (!dir.exists(dir)) stop("no such dir: ", dir)

  # files belonging to this origin: explicit list for the atlases (their 2 annots
  # only, since the atlas dirs hold many atlases), glob of the dir for the
  # mesh/registration origins (one origin per dir, minus .json/.txt records and
  # subdirectories).
  if (!is.null(origin$files)) {
    files <- origin$files
  } else {
    files <- list.files(dir, full.names = FALSE)
    files <- files[!grepl("\\.(json|txt)$", files)]
    files <- files[!dir.exists(file.path(dir, files))]
  }
  if (!length(files)) stop("no files found for origin ", atlas, " in ", space)

  checksums <- list()
  for (f in files) {
    rel <- file.path(space, f)
    checksums[[rel]] <- paste0("sha256:", sha256_rel(rel, repo))
  }

  att <- read_attribution(origin, repo)

  prov <- list(
    atlas = atlas,
    space = space,
    derived = FALSE,
    origin = "download",
    source_url = att$source_url,
    acquired_at = att$acquired_at,
    attribution_file = att$attribution_file
  )
  mi <- mesh_info[[space]]
  if (!is.null(mi)) {
    prov$mesh <- mi$mesh
    prov$mesh_n_vertices <- mi$mesh_n_vertices
  }
  if (!is.na(att$source_doi)) prov$source_doi <- att$source_doi
  prov$checksums <- checksums
  prov$generated_at <- today

  # drop NULL / NA scalar fields so the JSON stays clean
  prov <- prov[!vapply(prov, function(x) is.null(x) || (length(x) == 1L && is.na(x)), logical(1))]

  out <- file.path(repo, space, sprintf("%s.provenance.json", atlas))
  jsonlite::write_json(prov, out, pretty = TRUE, auto_unbox = TRUE)
  cat(sprintf("wrote %s (%d files)\n", out, length(files)))
}
