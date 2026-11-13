version 1.0

task vg_pack {
    
    input {
    File? in_gbz_file
    File? in_gaf_file
    String in_sample_name
    Int Q = 5
    Int threads = 8
    Int nb_cores = 16
    String mem_gb = 120
    Int disk_size = 6
    }
        
    command <<<
        vg pack \
        -x ~{in_gbz_file} \
        -a ~{in_gaf_file} \
        -Q ~{Q} \
        -t ~{threads} \
        -o ~{in_sample_name}.pack
    >>>

    output {
        File output_pack = "~{in_sample_name}.pack"
    }

    runtime {
        preemptible: 2
        time: 300
        memory: mem_gb + " GB"
        cpu: nb_cores
        disks: "local-disk " + disk_size + " SSD"
        docker: "quay.io/vgteam/vg:v1.66.0"
    }
}

task vg_call {
    
    input {
    File? in_gbz_file
    File? in_pack_file
    File? paths_list
    String in_sample_name
    Int minlen = 30
    Int threads = 8
    Int nb_cores = 16
    String mem_gb = 120
    Int disk_size = 6
    }

    command <<<
        RPATHS=""
        
        for RP in `cat ~{paths_list}`
        do
            RPATHS=`echo "-p $RP $RPATHS"`
        done

        cat ~{paths_list}

        vg call \
        -t ~{threads} \
        -k ~{in_pack_file} \
        -aAz \
        $RPATHS \
        -s ~{in_sample_name} \
        -c ~{minlen} \
        ~{in_gbz_file} \
        | gzip > ~{in_sample_name}.vcf.gz
    >>>

    output {
        File output_call = "~{in_sample_name}.vcf.gz"
    }

    runtime {
        preemptible: 2
        time: 300
        memory: mem_gb + " GB"
        cpu: nb_cores
        disks: "local-disk " + disk_size + " SSD"
        docker: "quay.io/vgteam/vg:v1.66.0"
    }
}
