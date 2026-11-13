version 1.0

task mergeGAF {
    input {
        String in_sample_name
        Array[File] in_gaf_chunk_files
        Int in_disk = round(3*size(in_gaf_chunk_files, 'G')) + 20
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

        cat ~{sep=" " in_gaf_chunk_files} > ~{in_sample_name}.gaf.gz
    >>>
    
    output {
        File output_merged_gaf = "~{in_sample_name}.gaf.gz"
    }

    runtime {
        preemptible: 2
        time: 300
        memory: "6GB"
        cpu: 1
        disks: "local-disk " + in_disk + " SSD"
        docker: "quay.io/vgteam/vg:v1.66.0"
    }
}