# HIC Workflow

Snakemake workflow for QC and processing of HIC data. Results in on .cool file and TAD calls for the data. All commands used to QC, and process hic-data are contianed in the main Snakefile.

**Prep**:

Place raw HIC reads in a new directory data/raw

```
mkdir -p data/raw
ln -s /path/to/some/data/*.fastq.gz data/raw/
```

**Configure the file**: src/config.yml

Generate Arima HIC genome restriction site file using the [hicup](https://www.bioinformatics.babraham.ac.uk/projects/hicup/) command [hicup_digester](https://www.bioinformatics.babraham.ac.uk/projects/hicup/) with the flag `--arima` is using the Arima HIC protocol.


All commands used to QC, and process hic-data are contianed in the main Snakefile. The pipeline uses conda for dependency management. Make sure you have installed a recent version of snakemake and conda.

**Execution**:

```
snakemake --use-conda -j20
```
