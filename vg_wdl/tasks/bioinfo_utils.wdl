version 1.0

task splitReads {
    input {
        File in_read_file
        String in_pair_id
        Int in_reads_per_chunk
        Int in_split_read_cores
        Int in_split_read_disk = 5 * round(size(in_read_file, "G")) + 20
    }

    command <<<
        # Set the exit code of a pipeline to that of the rightmost command
        # to exit with a non-zero status, or zero if all commands of the pipeline exit
        set -o pipefail
        # cause a bash script to exit immediately when a command fails
        set -e
        # cause the bash shell to treat unset variables as an error and exit immediately
        set -u
        # echo each line of the script to stdout so we can see what is happening
        set -o xtrace
        #to turn off echo do 'set +o xtrace'

        CHUNK_LINES=$(( ~{in_reads_per_chunk} * 4 ))
        gzip -cd ~{in_read_file} | split -l $CHUNK_LINES --filter='pigz -p ~{in_split_read_cores} > ${FILE}.fq.gz' - "fq_chunk_~{in_pair_id}.part."
    >>>
    output {
        Array[File] output_read_chunks = glob("fq_chunk_~{in_pair_id}.part.*")
    }
    runtime {
        preemptible: 2
        time: 120
        cpu: in_split_read_cores
        memory: "2 GB"
        disks: "local-disk " + in_split_read_disk + " SSD"
        docker: "quay.io/glennhickey/pigz:2.3.1"
    }
}

task convertCRAMtoFASTQ {
    input {
	    File? in_cram_file
        File? in_ref_file
        File? in_ref_index_file
	    Int in_cores
        Int disk_size = round(5 * size(in_cram_file, 'G')) + 50
    }
    Int half_cores = in_cores / 2
    command <<<
    # Set the exit code of a pipeline to that of the rightmost command
    # to exit with a non-zero status, or zero if all commands of the pipeline exit
    set -o pipefail
    # cause a bash script to exit immediately when a command fails
    set -e
    # cause the bash shell to treat unset variables as an error and exit immediately
    set -u
    # echo each line of the script to stdout so we can see what is happening
    set -o xtrace
    #to turn off echo do 'set +o xtrace'

    samtools collate -@ ~{half_cores} --reference ~{in_ref_file} -Ouf ~{in_cram_file} | samtools fastq -@ ~{half_cores} -1 reads.R1.fastq.gz -2 reads.R2.fastq.gz -0 reads.o.fq.gz -s reads.s.fq.gz -c 1 -N -
    >>>
    output {
        File output_fastq_1_file = "reads.R1.fastq.gz"
        File? output_fastq_2_file = "reads.R2.fastq.gz"
    }

    runtime {
        preemptible: 2
        cpu: in_cores
        memory: "50 GB"
        disks: "local-disk " + disk_size + " SSD"
        docker: "quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1"
    }    
}

task kmerCountingKMC {
    input {
        File input_read_file_1
        File? input_read_file_2
        String output_file_name

        Int kmer_length
        Int max_ram = 64
	    Int nb_cores = 16
        Int disk_size = round(size(input_read_file_1, "G") + size(input_read_file_2, "G")) + 10
    }

    command <<<
    # Set the exit code of a pipeline to that of the rightmost command
    # to exit with a non-zero status, or zero if all commands of the pipeline exit
    set -o pipefail
    # cause a bash script to exit immediately when a command fails
    set -e
    # cause the bash shell to treat unset variables as an error and exit immediately
    set -u
    # echo each line of the script to stdout so we can see what is happening
    set -o xtrace
    #to turn off echo do 'set +o xtrace'

    echo ~{input_read_file_1} > scratch_file.txt
    ~{if defined(input_read_file_2) then "echo ~{input_read_file_2} >> scratch_file.txt" else ""}

    kmc -k~{kmer_length} -m~{max_ram} -okff -t~{nb_cores} @scratch_file.txt ~{output_file_name} .

    rm scratch_file.txt
    >>>
    output {
        File kff_file = output_file_name + ".kff"
    }
    runtime {
        preemptible: 2
        cpu: nb_cores
        memory: max_ram + " GB"
        disks: "local-disk " + disk_size + " SSD"
        docker: "quay.io/biocontainers/kmc:3.2.1--hf1761c0_2"
    }
}
