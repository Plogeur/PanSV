rule pack:
    input:
        gbz="results/gbz/{graph}.sample_pg.all.gbz",
        gaf="results/sample/{sample}.{graph}.gaf.gz"
    output: tempCond('results/sample/{sample}.{graph}.pack')
    threads: 8
    priority: 3
    benchmark: 'benchmark/{sample}.{graph}.pack.benchmark.tsv'
    log: 'logs/pack.{graph}.{sample}.log'
    container: docker_imgs['vg']
    shell: "vg pack -x {input.gbz} -a {input.gaf} -Q 5 -t {threads} -o {output} 2> {log}"

rule vgcall:
    input: 
        gbz="results/gbz/{graph}.sample_pg.all.gbz",
        paths_list=config['ref_paths_list'],
        pack='results/sample/{sample}.{graph}.pack'
    output: tempCond('results/sample/{sample}.{graph}.gt.minlen{minlen}.vcf.gz')
    threads: 8
    priority: 4
    benchmark: 'benchmark/{sample}.{graph}.vgcall.minlen{minlen}.benchmark.tsv'
    container: docker_imgs['vg']
    shell:
        """
        RPATHS=""
        for RP in `cat {input.paths_list}`
        do
        RPATHS=`echo "-p $RP $RPATHS"`
        done

        vg call -t {threads} -k {input.pack} -Az $RPATHS -s {wildcards.sample} -c {wildcards.minlen} {input.gbz} | gzip > {output}
        """
