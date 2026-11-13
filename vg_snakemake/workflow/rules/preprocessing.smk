wildcard_constraints:
    run="[^_]+"

rule download_single:
    output:
        "data/{run}.fastq.gz"
    threads: 4
    resources:
        mem_mb=16000,
        runtime=240
    log:
        "logs/download/{run}.log"
    shell:
        """
        prefetch {wildcards.run} --max-size 100G >> {log} 2>&1

        fasterq-dump {wildcards.run} \
            --threads {threads} \
            -O data >> {log} 2>&1

        gzip -f data/{wildcards.run}.fastq
        """

rule download_paired:
    output:
        "data/{run}_R1.fastq.gz",
        "data/{run}_R2.fastq.gz"
    threads: 4
    resources:
        mem_mb=16000,
        runtime=240
    log:
        "logs/download/{run}.log"
    shell:
        """
        prefetch {wildcards.run} --max-size 100G >> {log} 2>&1

        fasterq-dump {wildcards.run} \
            --threads {threads} \
            --split-files -O data >> {log} 2>&1

        gzip -f data/{wildcards.run}_1.fastq
        gzip -f data/{wildcards.run}_2.fastq

        mv data/{wildcards.run}_1.fastq.gz data/{wildcards.run}_R1.fastq.gz
        mv data/{wildcards.run}_2.fastq.gz data/{wildcards.run}_R2.fastq.gz
        """
