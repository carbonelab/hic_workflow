#Snakefile for processing HiC data
import glob
configfile: "src/config.yml"

merged_prefix = config["MERGE_PFX"]
print(f"Samples will be named using the prefix: {merged_prefix}")

samples=config["SAMPLES"]
print("Running pipeline on  "+samples)
reads=[v for s in samples for v in [s+"_1", s+"_2"]]

rule all:
    input:
        expand("data/fastqc/{read}.html", read=reads),
        expand("data/pairix/{sample}.bsorted.pairs.gz", sample=samples),
        expand(["data/pairix/{merged_prefix}.pairs.gz",
               "data/cool/{merged_prefix}.cool",
               "data/cool/{merged_prefix}.mcool",
               "data/TADs/{merged_prefix}_min10_max60_fdr01_d01_boundaries.bed",
               "data/TADs/{merged_prefix}_min30_max100_fdr01_d001_boundaries.bed",
               ], merged_prefix=merged_prefix),
        "data/multiqc/multiqc_report.html"


# run fastqc on R1 and R2 for all samples
rule fastqc:
    input:
        "data/raw/{read}.fastq.gz"
    output:
        html="data/fastqc/{read}.html",
	zip="data/fastqc/{read}_fastqc.zip"
    log:
        "data/logs/fastqc_{read}.log"
    params:
        "--threads 4"
    wrapper:
        "v1.5.0/bio/fastqc"

# run hicup pipeline 
rule hicup:
    input:
       "data/raw/{sample}_1.fastq.gz", "data/raw/{sample}_2.fastq.gz"
    output:
       "data/hicup/{sample}_1_2.hicup.bam"
    params:
        index = config["GENOME"],
        digest = lambda wildcards: config["DIGEST"][wildcards.sample],
    threads: 16 
    conda:
        "envs/hic.yml"
    log:
        "data/logs/hicup_{sample}.log"
    shell:
        "hicup --bowtie2 $(which bowtie2) --digest {params.digest} "
        "--format Sanger "
        "--index {params.index} "
        "--longest 800 "
        "--zip "
        "--outdir data/hicup "
        "--shortest 50 "
        "--threads {threads} "
        "{input} >{log} 2>&1"

rule bam2pairs:
    input:
        "data/hicup/{sample}_1_2.hicup.bam"
    output:
        "data/pairix/{sample}.bsorted.pairs.gz"
    conda:
        "envs/hic.yml"
    log:
        "data/logs/bam2pairs.{sample}.log"
    shell:
    # -c -p to uniqify @SQ and @PG
        "bam2pairs -c {config[CHRSIZES]} {input} data/pairix/{wildcards.sample} >{log} 2>&1"

# merge samples for best resolution = best quality boundary calls
rule merge_pairs:
    input:
        expand("data/pairix/{sample}.bsorted.pairs.gz", sample=samples)
    output:
        f"data/pairix/{merged_prefix}.pairs.gz"
    conda:
        "envs/hic.yml"
    params:
        prefix=merged_prefix
    shell:
        "merge-pairs.sh data/pairix/{params.prefix} {input}"

# make coolers
rule cooler_cload:
    input:
        rules.merge_pairs.output
    output:
        f"data/cool/{merged_prefix}.cool"
    conda:
        "envs/hic.yml"
    log:
        expand("data/logs/cooler_cload.{merged_prefix}.log",  merged_prefix=merged_prefix)
    threads: 16 
    shell:
        "cooler cload pairix -p {threads} --assembly {config[ASMBLY]} {config[CHRSIZES]}:10000 {input} {output} >{log} 2>&1"

# create multiple resolution coolers for visualization in higlass
rule zoomify:
    input:
        rules.cooler_cload.output
    output:
        "data/cool/{merged_prefix}.mcool"
    log:
        "data/logs/zoomify.{merged_prefix}.log"
    conda:
        "envs/hic.yml"
    threads: 16 
    shell:
        "cooler zoomify -p {threads} --balance -o {output} {input} >{log} 2>&1"

# find TADs using hicFindTADs from hicExplorer at 10kb resolution
rule hicFindTADs:
    input:
        "data/cool/{merged_prefix}.mcool"
    output:
        "data/TADs/{merged_prefix}_min10_max60_fdr01_d01_boundaries.bed"
    conda:
        "envs/hicexplorer.yml"
    log:
        "data/logs/hicFindTADs_narrow.{merged_prefix}.log"
    threads: 16
    shell:
        "hicFindTADs -m {input}::resolutions/10000 --minDepth 100000 --maxDepth 600000 --outPrefix data/TADs/{wildcards.merged_prefix}_min10_max60_fdr01_d01 --correctForMultipleTesting fdr -p {threads} >{log} 2>&1"

rule multiqc:
    input:
       expand("data/hicup/{sample}_1_2.hicup.bam", sample=samples), "data"
    output:
        "data/multiqc/multiqc.html"
    log:
        "data/logs/multiqc.log"
    wrapper:
        "v1.5.0/bio/multiqc"
