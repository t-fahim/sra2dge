# sra2dge

**sra2dge** is a pipeline for differential gene expression (DGE) analysis starting directly from raw sequencing data deposited in the NCBI Sequence Read Archive (SRA). It automates the workflow from raw reads to a final list of differentially expressed genes, using **DESeq2** for the statistical analysis.

The goal of this project is to provide a reproducible, end-to-end path from public SRA accessions to publication-ready differential expression results and visualizations, removing the manual overhead of stitching together download, alignment/quantification, and statistical testing steps.

## Table of Contents

- [sra2dge](#sra2dge)
  - [Table of Contents](#table-of-contents)
  - [Business Understanding](#business-understanding)
  - [Data Understanding](#data-understanding)
  - [Screenshots / Visualizations](#screenshots--visualizations)
  - [Technologies](#technologies)
  - [Setup](#setup)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
    - [Option 1: Direct Launch](#option-1-direct-launch)
    - [Option 2: From Inside RStudio](#option-2-from-inside-rstudio)
    - [Usage](#usage)
  - [Approach](#approach)
  - [Status](#status)
  - [Credits](#credits)

## Business Understanding

Differential gene expression analysis is a common but often repetitive task in bioinformatics: pull raw reads from SRA, quantify expression, and run a statistical model to find genes that differ between conditions. Doing this manually for every new dataset is time-consuming and error-prone, especially in keeping steps consistent and reproducible across projects.

`sra2dge` was built to streamline this process into a single, repeatable pipeline — from an SRA accession number to a DESeq2 results table — so that the same, well-tested workflow can be applied to any new RNA-seq dataset with minimal setup.

Challenges addressed by this project include:

- Automating and standardizing the download and quality control of SRA data.
- Handling variable read quality and library types across different SRA submissions.
- Ensuring the DESeq2 design/model is correctly specified based on the experiment's metadata.

_(Fill in specifics: what motivated this project, what dataset(s) prompted it, and any particular challenges you ran into.)_

## Data Understanding

Data for this project comes from the **NCBI Sequence Read Archive (SRA)**, a public repository of raw sequencing data from a wide range of studies.

_(Describe here: which SRA study/accession(s) you used, the experimental design — e.g., treatment vs. control, number of replicates — the organism, and why this dataset was chosen. Also note any planned enhancements, such as adding support for additional organisms, alternative quantification tools, or batch-effect correction.)_

## Screenshots / Visualizations

_(Add example outputs here, such as:)_

- PCA plot of samples
- MA plot of differential expression results
- Volcano plot of significant genes
- Heatmap of top differentially expressed genes

## Technologies

- **R** / **Bioconductor**
  - `DESeq2` — differential expression analysis
  - `tximport` / `tximeta` — importing quantification results (if applicable)
  - `ggplot2`, `pheatmap`, `EnhancedVolcano` — visualization
- **SRA Toolkit** (`prefetch`, `fasterq-dump`) — downloading raw reads from SRA
- **Quality control**: `FastQC`, `MultiQC`
- **Trimming**: `Trim Galore` / `fastp`
- **Alignment / Quantification**: e.g., `Salmon`, `STAR`, or `HISAT2` + `featureCounts`
- **Workflow management**: e.g., `Snakemake` / `Nextflow` / shell scripts (specify which)
- **Python** (if used for pipeline orchestration or auxiliary scripts)

_(Update this list to match the exact tools and versions your pipeline actually uses.)_

## Setup

### Prerequisites

- R (version 4.6.1 or higher) with Bioconductor installed
- SRA Toolkit
- RStudio

### Installation

```bash
# Clone the repository
git clone https://github.com/t-fahim/sra2dge.git
cd sra2dge
```

To open and run this project in RStudio using the `.Rproj` file:

### Option 1: Direct Launch

Double-click the `.Rproj` file in your file explorer. This will automatically launch RStudio with the working directory set to the project root.

### Option 2: From Inside RStudio

1. Open **RStudio**.
2. Go to the top menu and select **File** > **Open Project...**
3. Navigate to the project directory, select the `.Rproj` file, and click **Open**.

### Usage

```bash
# Example: run the pipeline on a given SRA accession
./sra2dge.sh --accession SRPXXXXXX --outdir results/
```

```r
# Example: run the DESeq2 step directly in R
source("scripts/run_deseq2.R")
run_deseq2(counts_file = "results/counts.tsv",
           metadata_file = "results/metadata.csv",
           design = ~ condition)
```

_(Replace the above with your project's actual entry point, script names, and required arguments.)_

## Approach

1. **Data Acquisition** — Download raw FASTQ files from SRA using the SRA Toolkit, given one or more accession numbers.
2. **Quality Control** — Run FastQC/MultiQC on raw reads; trim adapters and low-quality bases as needed.
3. **Alignment / Quantification** — Align reads to a reference genome/transcriptome or pseudo-align/quantify transcript abundance.
4. **Count Matrix Generation** — Aggregate per-sample quantification into a single gene-level count matrix.
5. **Differential Expression Analysis** — Load counts and sample metadata into **DESeq2**, specify the experimental design, and run the standard DESeq2 workflow (normalization, dispersion estimation, hypothesis testing).
6. **Results & Visualization** — Extract significant genes (based on adjusted p-value / log2 fold-change thresholds) and generate summary plots (PCA, MA plot, volcano plot, heatmap).

_(Expand each step with the specific parameters, thresholds, and design formulas you used.)_

## Status

**In progress.**

current version : v0.1.0.

## Credits

_(List any individuals, organizations, tutorials, or resources that helped you build this project — for example, the DESeq2 documentation/vignette, SRA Toolkit documentation, or collaborators.)_
