vg\_wdl
---------------
Eric T Dawson, Mike Lin and Charles Markello, Jean Monlong, Adam Novak
MIT License, 2023

[Workflow Description Language (WDL)](https://software.broadinstitute.org/wdl/documentation/quickstart) scripts
for [vg](https://github.com/vgteam/vg) workflows.

- [Workflows](#Workflows)
- [Usage](#usage)
- [Testing locally](#Testing-locally)
- [Citation](#citation)
- [Contributing, Help, Bugs and Requests](#Contributing-Help-Bugs-and-Requests)

## Workflows

### Giraffe workflow

Core VG Giraffe mapping, usable for [DeepVariant](https://github.com/google/deepvariant).
Reads are mapped to a pangenome with [vg giraffe](https://github.com/vgteam/vg) and pre-processed (e.g. indel
realignment).

- workflow file: [workflows/giraffe.wdl](workflows/giraffe.wdl)
- [Dockstore page](https://dockstore.org/workflows/github.com/vgteam/vg_wdl/Giraffe:gbz?tab=info)
- If you use this workflow, please cite [the HPRC preprint](#cite-HPRC).

Parameters (semi-auto-generated from the *parameter_meta* section):

- *INPUT_READ_FILE_1*: Input sample 1st read pair fastq.gz
- *INPUT_READ_FILE_2*: Input sample 2nd read pair fastq.gz
- *INPUT_CRAM_FILE*: Input CRAM file
- *CRAM_REF*: Genome fasta file associated with the CRAM file
- *CRAM_REF_INDEX*: Index of the fasta file associated with the CRAM file
- *GBZ_FILE*: Path to .gbz index file
- *SAMPLE_NAME*: The sample name
- *OUTPUT_GAF*: Should a GAF file with the aligned reads be saved? Default is 'false'.
- *PAIRED_READS*: Are the reads paired? Default is 'true'.
- *READS_PER_CHUNK*: Number of reads contained in each mapping chunk. Default 20 000 000.
- *PATH_LIST_FILE*: (OPTIONAL) Text file where each line is a path name in the GBZ index, to use instead of CONTIGS. If
  neither is given, paths are extracted from the GBZ and subset to chromosome-looking paths.
- *CONTIGS*: (OPTIONAL) Desired reference genome contigs, which are all paths in the GBZ index.
- *GIRAFFE_OPTIONS*: (OPTIONAL) extra command line options for Giraffe mapper
- *SPLIT_READ_CORES*: Number of cores to use when splitting the reads into chunks. Default is 8.
- *MAP_CORES*: Number of cores to use when mapping the reads. Default is 16.
- *MAP_MEM*: Memory, in GB, to use when mapping the reads. Default is 120.
- *IN_DIPLOID*:Whether or not to use diploid sampling while doing haplotype sampling. Has to use with Haplotype_sampling=true. Default is 'true'
- *HAPL_FILE*: (OPTIONAL) Path to .hapl file used in haplotype sampling
- *IN_HAPLOTYPE_NUMBER*: Number of generated synthetic haplotypes used in haplotype sampling. (Default: 4)

Related
topics: [read realignment](#Read-realignment), [reference prefix removal](#Reference-prefix-removal), [CRAM input](#CRAM-input), [reads chunking](#Reads-chunking), [path list](#Path-list), [single-end reads](#Single-end-reads), [unmapped reads](#Unmapped-reads), [HPRC pangenomes](#HPRC-pangenomes), [Haplotype Sampling](#Haplotype-Sampling-workflow).

[Test locally](#testing-locally) with:

```sh
miniwdl run --as-me workflows/giraffe.wdl -i params/giraffe.json
miniwdl run --as-me workflows/giraffe.wdl -i params/giraffe.singleended.json
miniwdl run --as-me workflows/giraffe.wdl -i params/giraffe.singleended.cram.json
```

### Going further

See below more information
about: [read realignment](#Read-realignment), [reference prefix removal](#Reference-prefix-removal), [CRAM input](#CRAM-input), [reads chunking](#Reads-chunking), [path list](#Path-list), [single-end reads](#Single-end-reads), [unmapped reads](#Unmapped-reads), [HPRC pangenomes](#HPRC-pangenomes).

#### Read realignment

Once the reads are projected to a linear reference, we've noticed that realigning the reads can improve the variant
calling with [DeepVariant](https://github.com/google/deepvariant).
This helps mostly for the small insertions-deletions (indels).

The full realignment process involves:

1. Leftaligning the reads
   with [freebayes' `bamleftalign`](https://manpages.debian.org/testing/freebayes/bamleftalign.1.en.html).
    - Can be enabled/disabled with the `LEFTALIGN_BAM` parameter
2. Identifying regions to realign further
   with [GATK RealignerTargetCreator](https://github.com/broadinstitute/gatk-docs/blob/master/gatk3-tutorials/(howto)_Perform_local_realignment_around_indels.md).
3. Expand those regions with [bedtools](https://bedtools.readthedocs.io/en/latest/content/tools/slop.html).
    - Number of bases to expand controlled by the `REALIGNMENT_EXPANSION_BASES` parameter.
4. Realigning the reads in those regions with [ABRA2](https://github.com/mozack/abra2).

The last 3 steps can be enabled/disabled with the `REALIGN_INDELS` parameter.

Although it produces the best variant calls, these extra steps increase the computational resources (and cost) of the
workflow.
For a lighter run, switch off those two realignment steps and use [DeepVariant](https://github.com/google/deepvariant)'s
integrated realigner instead with:

- `LEFTALIGN_BAM=false`
- `REALIGN_INDELS=false`
- `DV_NORM_READS=true`

#### Reference prefix removal

The names of contigs/paths/haplotypes in pangenomes sometimes contains a prefix that we'd want to remove.
In the HPRC pangenomes, for example, the chromosomal contigs from GRCh38 are named *GRCh38.chr1*, etc.
In practice, we want to remove this prefix from the variant calls (VCFs), or reads aligned to that reference (BAMs).

This is controlled by the `REFERENCE_PREFIX` parameters in the workflows.
Setting `REFERENCE_PREFIX="GRCh38."` for example will ensure the VCFs/BAMs have *chr1*, etc. for contig names.

Because the pangenome uses them, **the prefix must still be present when specifying the paths to project the reads** too
though.
Hence, the `CONTIGS` and `PATH_LIST_FILE` must use the prefix.

However, **provided reference FASTAs or dictionary must not have the prefix**.
These could be FASTA or `.dict` files from the "official" reference genome or pre-computed for them, hence no prefix.
So, no prefix in `REFERENCE_FILE`, `REFERENCE_INDEX_FILE`, `REFERENCE_DICT_FILE`.

#### CRAM input

When the input is a CRAM file (`INPUT_CRAM_FILE`) instead of a pair of FASTQ
files (`INPUT_READ_FILE_1`/`INPUT_READ_FILE_2`), the user must also provide the appropriate reference FASTA to work with
that CRAM file with `CRAM_REF`, and its index with `CRAM_REF_INDEX`.

The CRAM file will be converted back to a pair of FASTQs, so it costs a little bit more to analyze CRAMs than FASTQs
currently.

#### Reads chunking

Sequencing reads are chunked to parallelize read mapping.
The amount of chunking is controlled by the `READS_PER_CHUNK` parameter which specify how many reads each chunk should
have.
For a WGS experiment, we use chunks of about 20M reads.

#### Path list

We might not always want to project the reads alignments to all the paths in the pangenome.
For example, we might only care about alignment to chromosomes and not alternate contigs.
Or there might be multiple sets of paths like in the CHM13-based HPRC pangenome which contains both reference paths for
CHM13 and GRCh38.
In that case, we can specify a list of paths to project the reads to using one of the following.

`PATH_LIST_FILE` is a file which lists the paths names, one per line.
For the HPRC pangenomes it looks like:

```txt
GRCh38.chr1
GRCh38.chr2
GRCh38.chr3
...etc
```

Otherwise, paths can be listed in the `CONTIGS` parameter as a list (WDL array).

#### Unmapped reads

If including unmapped reads in the BAMs is important, make sure to switch on `OUTPUT_SINGLE_BAM=true` in
the [Giraffe-DeepVariant workflow](#Giraffe-DeepVariant-workflow) and [Giraffe workflow](#Giraffe-workflow).

#### HPRC pangenomes

We recommend using the filtered CHM13-based pangenome (freeze 1).
It contains both the CHM13 and GRCh38 reference paths.

Use the following indexes for the pangenome:

- `GBZ_FILE`: [hprc-v1.0-mc-chm13-minaf.0.1.gbz](https://storage.googleapis.com/hprc-pangenomes/hprc-v1.0-mc-chm13-minaf.0.1.gbz)
    - GBZ with the pangenome and haplotypes.
- `MIN_FILE`: [hprc-v1.0-mc-chm13-minaf.0.1.min](https://s3-us-west-2.amazonaws.com/human-pangenomics/pangenomes/freeze/freeze1/minigraph-cactus/filtered/hprc-v1.0-mc-chm13-minaf.0.1.min)
    - Minimizer index.
- `DIST_FILE`: [hprc-v1.0-mc-chm13-minaf.0.1.dist](https://s3-us-west-2.amazonaws.com/human-pangenomics/pangenomes/freeze/freeze1/minigraph-cactus/filtered/hprc-v1.0-mc-chm13-minaf.0.1.dist)
    - Distance index.

To project reads and call variants relative to the GRCh38 reference:

- `REFERENCE_PREFIX="GRCh38."`
- `PATH_LIST_FILE` containing *GRCh38.chr1*, *GRCh38.chr2*, etc. File available
  at [GRCh38.path_list.txt](https://storage.googleapis.com/hprc-pangenomes/GRCh38.path_list.txt)
- `REFERENCE_FILE`: [hg38.fa](https://storage.googleapis.com/hprc-pangenomes/hg38.fa)
- `REFERENCE_INDEX_FILE`: [hg38.fa.fai](https://storage.googleapis.com/hprc-pangenomes/hg38.fa.fai). Optional, the
  workflow will create it if necessary (for a small extra cost/time).
- `REFERENCE_DICT_FILE`: [hg38.dict](https://storage.googleapis.com/hprc-pangenomes/hg38.dict). Optional, the workflow
  will create it if necessary (for a small extra cost/time).

To project reads and call variants relative to the CHM13 reference:

- `REFERENCE_PREFIX="CHM13."`
- `PATH_LIST_FILE` containing *CHM13.chr1*, *CHM13.chr2*, etc. File available
  at [CHM13.path_list.txt](https://storage.googleapis.com/hprc-pangenomes/CHM13.path_list.txt)
- `REFERENCE_FILE`: [chm13v2.0.plus_hs38d1_analysis_set.compact_decoys.fa](https://storage.googleapis.com/hprc-pangenomes/chm13v2.0.plus_hs38d1_analysis_set.compact_decoys.fa)
- `REFERENCE_INDEX_FILE`: [chm13v2.0.plus_hs38d1_analysis_set.compact_decoys.fa.fai](https://storage.googleapis.com/hprc-pangenomes/chm13v2.0.plus_hs38d1_analysis_set.compact_decoys.fa.fai).
  Optional, the workflow will create it if necessary (for a small extra cost/time).
- `REFERENCE_DICT_FILE`: [chm13v2.0.plus_hs38d1_analysis_set.compact_decoys.dict](https://storage.googleapis.com/hprc-pangenomes/chm13v2.0.plus_hs38d1_analysis_set.compact_decoys.dict).
  Optional, the workflow will create it if necessary (for a small extra cost/time).

For earlier versions of DeepVariant (<1.5), models were retrained using reads aligned to the HPRC pangenomes.
The corresponding model files were deposited
at: [https://s3-us-west-2.amazonaws.com/human-pangenomics/index.html?prefix=publications/PANGENOME_2022/DeepVariant/models/DEEPVARIANT_MC_Y1/](https://s3-us-west-2.amazonaws.com/human-pangenomics/index.html?prefix=publications/PANGENOME_2022/DeepVariant/models/DEEPVARIANT_MC_Y1/).
They can be passed to the workflows using the `DV_MODEL_META`, `DV_MODEL_INDEX`, and `DV_MODEL_DATA`.
Note that **it is not necessary to use custom models in the latest version of the workflows** as DeepVariant v1.5
includes default models suited for analyzing reads mapped to pangenomes (and projected back to a linear reference).

## Usage

### Dockstore

The workflows that were deposited on [Dockstore](https://dockstore.org/) can be launched
using [its command line](https://docs.dockstore.org/en/stable/launch-with/launch.html) or on platform
like [Terra](https://app.terra.bio/).

### Using miniwdl

[Install miniwdl](https://miniwdl.readthedocs.io/en/latest/getting_started.html#install-miniwdl), for example,
with `pip`:

```sh
pip3 install miniwdl
```

Clone this repo somewhere with `git clone https://github.com/vgteam/vg_wdl.git`

Run a workflow using:

```
miniwdl run /path/to/vg_wdl/workflows/WORKFLOW.wdl -i your-inputs.json
```

To modify the input parameters, edit the input `.json` with the necessary changes.

### Using Cromwell

[Cromwell](https://cromwell.readthedocs.io/en/stable/) can be run WDL workflows with:

```sh
java -jar $CROMWELL_JAR run workflow.wdl -i inputs.json
```

Where *CROMWELL_JAR* points at the Cromwell jar
downloaded [their release page](https://github.com/broadinstitute/cromwell/releases/), for example set
with `CROMWELL_JAR=/path/to/cromwell-<whatever>.jar` in your shell.

To run one of the workflows in this repo, clone the repo somewhere with `git clone https://github.com/vgteam/vg_wdl.git`
and run the desired workflow `.wdl` file:

```sh
java -jar $CROMWELL_JAR run /path/to/vg_wdl/workflows/WORKFLOW.wdl -i inputs.json
```

### Docker Containers

WDL needs the runtime Docker image to be present online (e.g. Dockerhub).
[Cromwell](#using-cromwell)/[miniwdl](#using-miniwdl) will pull those images automatically.
VG images are available at [quay.io](https://quay.io/repository/vgteam/vg?tab=tags) and can be pulled with:

```
docker pull quay.io/vgteam/vg:v1.66.0
```

Specific versions can be specified like above for version `v1.44.0`.

## Testing locally

To test the workflow locally, e.g. on the [small simulated dataset](tests/small_sim_graph), you can run it with Cromwell
or miniwdl (see [Usage](#usage)).
So, from the root of this repo, run something like:

```sh
java -jar $CROMWELL_JAR run workflows/WORKFLOW.wdl -i params/INPUTS.json
## or
miniwdl run --as-me workflows/WORKFLOW.wdl -i params/INPUTS.json
```

[Miniwdl](#using-miniwdl) might be slightly more useful when developing/testing a WDL because is catches errors in WDL
syntax faster, and is a bit more explicit about them.

## Citation

### Cite HPRC

If you use the Giraffe-DeepVariant workflows, please cite
the [HPRC preprint](https://www.biorxiv.org/content/10.1101/2022.07.09.499321v1):

```
Liao, Asri, Ebler, et al. A Draft Human Pangenome Reference. preprint, bioRxiv 2022; doi: https://doi.org/10.1101/2022.07.09.499321 
```

### Cite Giraffe-SV

If you use the SV genotyping workflow with vg giraffe, please
cite [this article](https://doi.org/10.1126/science.abg8871):

```
Sirén, Monlong, Chang, Novak, Eizenga, et al. Pangenomics Enables Genotyping of Known Structural Variants in 5202 Diverse Genomes. Science, vol. 374, no. 6574, Dec. 2021; doi: https://doi.org/10.1126/science.abg8871.
```

### Cite Pedigree-VG

If you use the pedigree-based workflow for rare variant discovery, please
cite [this article](https://pubmed.ncbi.nlm.nih.gov/35483961/):

```
Markello et al. A Complete Pedigree-Based Graph Workflow for Rare Candidate Variant Analysis. Genome Research, Apr. 2022; doi: https://doi.org/10.1101/gr.276387.121.
```

## Contributing, Help, Bugs and Requests

Please open an Issue on [GitHub](https://github.com/vgteam/vg_wdl/issues) for help, bug reports, or feature requests.
When doing so, please remember that vg\_wdl is open-source software made by a community of developers.
Please be considerate and support a positive environment.
