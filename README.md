# PanSV

The **PanSV** directory focuses on creating, benchmarking and testing various pipelines and tools used for **genotyping human samples** in the context of **structural variant (SV) discovery** and **GWAS** related to **hemochromatosis** in the *UK Biobank ANR* project.

## Contents

This section includes three main **pangenome genotyping pipelines**:

* [`pangenie`](pangenie/) : A pipeline for genotyping using the *PanGenie* tool.
* [`vg_snakemake`](vg_snakemake/) : A *Snakemake*-based pipeline using the *VG toolkit* for graph-based genotyping.
* [`vg_wdl`](vg_wdl_call/) : A *WDL*-based workflow for VG-based genotyping, enabling execution on scalable platforms.
