# brain_atlases


Commonly used brain atlases in neuroimaging research, for the `fsaverage` and `fs_LR_32` templates.

This repo collects well-known cortical atlases and standard template surfaces in a convenient, ready-to-use form. The atlases are **the work of their respective authors** — we only distribute (and in some cases convert) them, so please respect the original authors and their licenses, listed for each atlas  in this repo (see `Attribution & citation` section below for details).

We have converted many atlases that are orginally available only for the `FS_LR_32` meshes to `fsaverage`, via resampling them in Connectome Workbench. You can inspect the workflow that was used in the scripts in the [dev_tools directory](./dev_tools/).

## Layout

| Path | Contents |
|---|---|
| `atlas_fsaverage/` | Atlases on the FreeSurfer `fsaverage` template (163,842 verts/hemi): HCP-MMP1, plus `aparc`, `aal3`, `brainnetome`, `schaefer100`–`schaefer1000` (resampled from `fs_LR` 32k). |
| `atlas_fs_LR_32/` | Atlases on the `fs_LR` 32k template (32,492 verts/hemi): `aparc`, `aal3`, `brainnetome`, `schaefer100`–`schaefer1000`. |
| `template_subject_meshes/` | Standard template surfaces: `fsaverage/` (FreeSurfer) and `fs_LR_32/` (DiedrichsenLab), plus `registration/` (HCP deformation spheres + cortex ROIs used for the fs_LR ↔ fsaverage resampling). |
| `dev_tools/` | Conversion scripts: `convert_fsLR32_to_fsaverage.sh` resamples the `fs_LR` 32k atlases to `fsaverage` using the HCP deformation spheres (needs Connectome Workbench + FreeSurfer + R), `visualize_all.R` renders all atlases with the headless scimesh backend, `make_readme_previews.sh` builds the preview images shown in the [Gallery](#gallery) below, and `audit_annots.R` verifies the region counts of all atlases (see note below). |

> **Note on resampling lossiness:** the `fsaverage` versions of the atlases were resampled from `fs_LR` 32k with Connectome Workbench, which is lossy — tiny parcels can disappear during the resample. The only affected atlas is `schaefer1000`, whose right hemisphere has **498 instead of 500 parcels** on `fsaverage` (the `fs_LR` 32k version still has 499). Use `dev_tools/audit_annots.R` to verify the region counts of all atlases.


## Gallery

Full-resolution renders (4 views per atlas: lateral & medial of both hemispheres) of every atlas in this repo. Click any thumbnail to open the full-size image. The renders are produced by `dev_tools/visualize_all.R`; the previews by `dev_tools/make_readme_previews.sh`.

<details>
<summary><b>All fsaverage atlases at a glance (9)</b></summary>

![All fsaverage atlases](dev_tools/visualize_all_output/previews/fsaverage_all.png)

</details>

<details>
<summary><b>All fs_LR 32k atlases at a glance (8)</b></summary>

![All fs_LR 32k atlases](dev_tools/visualize_all_output/previews/fslr32_all.png)

</details>


Visually, the different Schaefer variants look the same, but they of course do have different regions counts, as illustrated by [the output](./dev_tools/audit_annots_output.txt) of our [audit script](./dev_tools/audit_annots.R).

### fsaverage template

| | | |
|---|---|---|
| [![HCP-MMP1](dev_tools/visualize_all_output/previews/fsaverage_HCPMMP1_thumb.png)](dev_tools/visualize_all_output/fsaverage_HCPMMP1.png) | [![aparc](dev_tools/visualize_all_output/previews/fsaverage_aparc_thumb.png)](dev_tools/visualize_all_output/fsaverage_aparc.png) | [![aal3](dev_tools/visualize_all_output/previews/fsaverage_aal3_thumb.png)](dev_tools/visualize_all_output/fsaverage_aal3.png) |
| [![brainnetome](dev_tools/visualize_all_output/previews/fsaverage_brainnetome_thumb.png)](dev_tools/visualize_all_output/fsaverage_brainnetome.png) | [![schaefer100](dev_tools/visualize_all_output/previews/fsaverage_schaefer100_thumb.png)](dev_tools/visualize_all_output/fsaverage_schaefer100.png) | [![schaefer200](dev_tools/visualize_all_output/previews/fsaverage_schaefer200_thumb.png)](dev_tools/visualize_all_output/fsaverage_schaefer200.png) |
| [![schaefer300](dev_tools/visualize_all_output/previews/fsaverage_schaefer300_thumb.png)](dev_tools/visualize_all_output/fsaverage_schaefer300.png) | [![schaefer400](dev_tools/visualize_all_output/previews/fsaverage_schaefer400_thumb.png)](dev_tools/visualize_all_output/fsaverage_schaefer400.png) | [![schaefer1000](dev_tools/visualize_all_output/previews/fsaverage_schaefer1000_thumb.png)](dev_tools/visualize_all_output/fsaverage_schaefer1000.png) |

### fs_LR 32k template

| | | | |
|---|---|---|---|
| [![aparc](dev_tools/visualize_all_output/previews/fsLR32_aparc_thumb.png)](dev_tools/visualize_all_output/fsLR32_aparc.png) | [![aal3](dev_tools/visualize_all_output/previews/fsLR32_aal3_thumb.png)](dev_tools/visualize_all_output/fsLR32_aal3.png) | [![brainnetome](dev_tools/visualize_all_output/previews/fsLR32_brainnetome_thumb.png)](dev_tools/visualize_all_output/fsLR32_brainnetome.png) | [![schaefer100](dev_tools/visualize_all_output/previews/fsLR32_schaefer100_thumb.png)](dev_tools/visualize_all_output/fsLR32_schaefer100.png) |
| [![schaefer200](dev_tools/visualize_all_output/previews/fsLR32_schaefer200_thumb.png)](dev_tools/visualize_all_output/fsLR32_schaefer200.png) | [![schaefer300](dev_tools/visualize_all_output/previews/fsLR32_schaefer300_thumb.png)](dev_tools/visualize_all_output/fsLR32_schaefer300.png) | [![schaefer400](dev_tools/visualize_all_output/previews/fsLR32_schaefer400_thumb.png)](dev_tools/visualize_all_output/fsLR32_schaefer400.png) | [![schaefer1000](dev_tools/visualize_all_output/previews/fsLR32_schaefer1000_thumb.png)](dev_tools/visualize_all_output/fsLR32_schaefer1000.png) |

## Convert fsaverage data layout to FreeSurfer subjects dir

To use the fsaverage data directly with FreeSurfer / fsbrain (as `$SUBJECTS_DIR`), run this copy script once:

```sh
bash atlas_fsaverage/subjects_dir/rearrange_into_subjects_dir.sh
export SUBJECTS_DIR="$PWD/atlas_fsaverage/subjects_dir"
```

This copies the fsaverage meshes into `fsaverage/surf/` and the atlas `.annot` files into `fsaverage/label/`. You can then copy this directory structure into your standard FreeSurfer subjects dir.

## Reproduction

All data was generated on **Ubuntu 24.04 LTS (x86_64)** with the following software:

| Software | Version |
|---|---|
| Connectome Workbench (`wb_command`) | 2.2.1 |
| FreeSurfer | 7.4.1 |
| R | 4.6.1 |
| R: `fsbrain` | 0.7.0 |
| R: `scimesh` | 0.3.4 |
| R: `freesurferformats` | 1.0.1 |
| ImageMagick (`montage`/`convert`) | 6.9.12 |
| Python: `yabplot` (fs_LR 32k atlas download) | 0.5.1 |
| Python: `neuromaps` (HCP registration spheres/ROIs) | 0.0.7 |

The `fs_LR` 32k atlases, template meshes, and HCP registration data are already included in this repo, so no downloads are needed to reproduce the derived files. Run, in this order:

```sh
# 1. Resample the fs_LR 32k atlases to fsaverage (needs wb_command + FreeSurfer + R)
bash dev_tools/convert_fsLR32_to_fsaverage.sh

# 2. Render all atlases as 4-view PNGs (needs R: fsbrain 0.7.0 + scimesh 0.3.4; visualize_all.R pins these versions)
Rscript dev_tools/visualize_all.R

# 3. Build the README preview images (needs ImageMagick)
bash dev_tools/make_readme_previews.sh

# 4. Optional: materialize the FreeSurfer subjects_dir layout
bash atlas_fsaverage/subjects_dir/rearrange_into_subjects_dir.sh
```

The HCP-MMP1 atlas was obtained separately from the Human Connectome Project (see `atlas_fsaverage/HCPMMP1.txt`).



## Atlases shipping with FreeSurfer

We do not provide atlases for fsaverage that come with FreeSurfer, just use them from your FreeSurfer installation:

In `$FREESURFER_HOME/subjects/fsaverage/label/` you will find e.g.:

* the Desikan–Killiany atlas (`lh/rh.aparc.annot`)
* the Destrieux atlas (`lh/rh.aparc.a2009s.annot`), and
* the Yeo et al. (2011) functional parcellations (`lh/rh.Yeo2011_7Networks_N1000.annot` and `lh/rh.Yeo2011_17Networks_N1000.annot`).

Note that the `aparc` atlas for fsaverage in this repo was converted from the fs_LR_32 version for development/comparison purposes only. We do not recommend to use it. Use the one that comes with FreeSurfer.


## Attribution & citation

- Every atlas has a companion `.txt` file (e.g. `atlas_fs_LR_32/aparc.txt`) that records the **author(s), source, license, and citation DOI**. Please read it before using an atlas.
- **Cite the original papers** if you use any atlas in your work — the DOIs are listed in the `.txt` files. The atlases belong to their respective research groups; this repository merely redistributes them.
- Template meshes come from their respective sources; see `template_subject_meshes/fs_LR_32/fs_LR_32k.txt` for the `fs_LR_32` surfaces and `template_subject_meshes/fsaverage/fsaverage.txt` for the `fsaverage` surfaces.


## Author and License

The scripts in this repo were written by, and the conversions performed by [Tim Schäfer](https://ts.rcmd.org).

We consider the atlases in converted formats a derivative work, so each converted atlas is under the license of the original one, of course. Once more, see the `.txt` files mentioned in the `Attribution & citation` section for each atlas.

If you desperately need to know a license for the conversion scripts, basically the stuff under [dev_tools/](./dev_tools/), I license these under the very permissive [MIT license](https://opensource.org/license/mit).

