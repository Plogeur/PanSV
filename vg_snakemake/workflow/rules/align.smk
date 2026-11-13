rule count_kmer_in_reads:
    input:
        list_fq=get_list_fastq_for_run(),
    output:
        temp("results/kff/fastq_all.kff")
    params:
        wdir="temp_kmc_all",
        ofile="results/kff/fastq_all",
        mem_gb=config['kmc_mem_gb'],
        filel="temp_kmc_filelist_all.txt"
    threads: 8
    benchmark:
        "benchmark/all.count_kmer_in_reads.benchmark.tsv"
    container:
        docker_imgs['kmc']
    shell:
        """
        rm -rf {params.wdir}
        mkdir -p {params.wdir}

        # Create file list
        echo {input.list_fq} > {params.filel}

        kmc -k29 -m{params.mem_gb} -okff -t{threads} @{params.filel} {params.ofile} {params.wdir}

        rm -r {params.filel} {params.wdir}
        """

rule map_short_reads_giraffe:
    input: 
        fq1=getfq1,
        fq2=getfq2,
        gbz="results/gbz/{graph}.sample_pg.all.gbz",
        dist="results/dist/{graph}.sample_pg.all.dist",
        min="results/min/{graph}.sample_pg.all.min"
    output:
        "results/run/{run}.{graph}.gaf.gz"
    threads: 8
    priority: 2
    benchmark:
        'benchmark/{run}.{graph}.map_short_reads_giraffe.benchmark.tsv'
    container:
        docker_imgs['vg']
    params:
        fastq=lambda wildcards, input: (
            f"-f {input.fq1} -f {input.fq2}"
            if input.fq2 != ""
            else f"-i -f {input.fq1}")
    shell:
        """
        vg giraffe --progress \
        --sample "{wildcards.run}" \
        --output-format gaf \
        {params.fastq} \
        -Z {input.gbz} \
        -d {input.dist} \
        -m {input.min} \
        -t {threads} | gzip > {output}
        """

rule gaf_merge_sample:
    input:
        lambda wc: expand(
            "results/run/{run}.{graph}.gaf.gz",
            run=DICT_SAMPLE_RUNS[str(wc.sample)],
            graph=wc.graph
        )
    output:
        tempCond("results/sample/{sample}.{graph}.gaf.gz")
    threads: 1
    benchmark:
        "benchmark/{sample}.{graph}.gaf_fuse.benchmark.tsv"
    params:
        script="../scripts/merge_gaf.py"
    shell:
        """
        python3 {params.script} -i {input} | gzip > {output}
        """

rule sample_haplotypes:
    input: 
        gbz=getgbz(),
        hapl=gethapl(),
        read_kmer='results/kff/fastq_all.kff'
    output: tempCond("results/gbz/{graph}.sample_pg.all.gbz")
    threads: 8
    priority: 1
    benchmark: 'benchmark/{graph}.sample_haplotypes.benchmark.tsv'
    container: docker_imgs['vg']
    shell:
        """
        vg haplotypes -v 2 -t {threads} \
        --num-haplotypes 4 \
        --present-discount 0.9 \
        --het-adjustment 0.05 \
        --absent-score 0.8 \
        --include-reference \
        --diploid-sampling \
        -i {input.hapl} \
        -k {input.read_kmer} \
        -g {output} {input.gbz}
        """
