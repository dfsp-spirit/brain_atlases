#!/usr/bin/env Rscript
# Convert a Workbench label GIFTI / masked metric file to a FreeSurfer annotation (.annot).
# Called by convert_fsLR32_to_fsaverage.sh.
#
# Usage: Rscript convert_labelgii_to_annot.R <keys.gii> <labeltable.gii> <out.annot>
#
#   <keys.gii>      : per-vertex label keys on the target mesh. This is the output of
#                     `wb_command -metric-mask` on the resampled label file (it is a
#                     metric whose values are the label keys; 0 = masked / medial wall).
#   <labeltable.gii>: the resampled label GIFTI file (before masking), which carries the
#                     LabelTable mapping keys to region names and colors.
#   <out.annot>     : output FreeSurfer annotation file.
#
# Notes:
#  - The colortable is restricted to the label keys actually used by vertices, so that
#    atlases whose left/right regions share a color code (e.g. the Desikan-Killiany
#    'aparc' atlas) keep correct region names per hemisphere.
#  - Alpha is set to 0 (the common FreeSurfer parcellation convention), so that the
#    color codes stay within 32-bit range (alpha=255 would overflow the annot format).

args <- commandArgs(TRUE)
if (length(args) < 3) {
  stop('Usage: Rscript convert_labelgii_to_annot.R <keys.gii> <labeltable.gii> <out.annot>')
}
keys_gii <- args[1]
labeltable_gii <- args[2]
out_annot <- args[3]

if (!requireNamespace('freesurferformats', quietly = TRUE)) stop('R package "freesurferformats" is required.')
if (!requireNamespace('gifti', quietly = TRUE)) stop('R package "gifti" is required.')
suppressMessages({ library(freesurferformats); library(gifti) })

# per-vertex label keys (masked metric; 0 = medial wall)
keys <- as.integer(gifti::read_gifti(keys_gii)$data[[1]])
# LabelTable from the resampled label file (key -> name + color)
lt <- gifti::read_gifti(labeltable_gii)$label
key <- as.integer(lt[, 'Key'])
nm <- rownames(lt)
r <- round(as.numeric(lt[, 'Red']) * 255)
gr <- round(as.numeric(lt[, 'Green']) * 255)
b <- round(as.numeric(lt[, 'Blue']) * 255)

# Keep only LabelTable entries whose key is actually used by at least one vertex.
used <- key %in% unique(keys)
key <- key[used]; nm <- nm[used]; r <- r[used]; gr <- gr[used]; b <- b[used]

# Strip hemisphere markers from region names. These annots are per-hemisphere (like
# FreeSurfer's own lh.aparc.annot), so markers such as L_/R_ (aparc), _L/_R (aal3,
# brainnetome) or _LH_/_RH_ (schaefer) are redundant and, for atlases whose left/right
# regions share a color code (aparc, schaefer300), actively misleading.
nm <- sub('^[LR]H?_', '', nm) # prefix L_/R_/LH_/RH_
nm <- sub('_[LR]H?$', '', nm) # suffix _L/_R/_LH/_RH
nm <- sub('_[LR]H?_', '_', nm) # infix _LH_/_RH_ -> single underscore

al <- rep(0L, length(key))
codes <- r + gr * 2^8 + b * 2^16 + al * 2^24

row_of_key <- match(keys, key)
if (anyNA(row_of_key)) {
  # Vertices whose key is not in the LabelTable (e.g. wb_command's 'unused' label for
  # target vertices that got no valid source data at the cortex/medial-wall boundary)
  # are treated as the 'unknown' / medial wall region.
  unknown_row <- which(key == 0L)
  if (length(unknown_row) == 1L) {
    row_of_key[is.na(row_of_key)] <- unknown_row
  } else {
    stop('label data contains keys not in the LabelTable and no key-0 (unknown) entry to map them to.')
  }
}
label_codes <- codes[row_of_key]

# Deterministic colortable order (by key), 'unknown' (key 0) first.
o <- order(key)
ct <- data.frame(struct_name = nm[o], r = r[o], g = gr[o], b = b[o], a = al[o], code = codes[o], stringsAsFactors = FALSE)
freesurferformats::write.fs.annot(out_annot, num_vertices = length(keys), colortable = ct, labels_as_colorcodes = label_codes)
cat(sprintf('wrote %s: %d vertices, %d regions\n', out_annot, length(keys), nrow(ct)))
