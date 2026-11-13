version 1.0

import "../tasks/bioinfo_utils.wdl" as utils
import "../tasks/gam_gaf_utils.wdl" as gautils
import "../tasks/vg_map_hts.wdl" as map
import "../tasks/vg_vcall.wdl" as cal
import "./haplotype_sampling.wdl" as hapl

workflow Giraffe {
    meta {
        description: "## Giraffe workflow \n Core VG Giraffe mapping, usable for DeepVariant. Reads are mapped to a pangenome with vg giraffe and pre-processed (e.g. indel realignment). More information at [https://github.com/vgteam/vg_wdl/tree/gbz#giraffe-workflow](https://github.com/vgteam/vg_wdl/tree/gbz#giraffe-workflow)."
    }

    parameter_meta {
        INPUT_READ_FILE_1: "Input sample 1st read pair fastq.gz"
        INPUT_READ_FILE_2: "Input sample 2nd read pair fastq.gz"
        INPUT_CRAM_FILE: "Input CRAM file"
        CRAM_REF: "Genome fasta file associated with the CRAM file"
        CRAM_REF_INDEX: "Index of the fasta file associated with the CRAM file"
        GBZ_FILE: "Path to .gbz index file"
        SAMPLE_NAME: "The sample name"
        OUTPUT_GAF: "Should a GAF file with the aligned reads be saved? Default is 'false'."
        READS_PER_CHUNK: "Number of reads contained in each mapping chunk. Default 20 000 000."
        PATH_LIST_FILE: "(OPTIONAL) Text file where each line is a path name in the GBZ index, to use instead of CONTIGS. If neither is given, paths are extracted from the GBZ and subset to chromosome-looking paths."
        CONTIGS: "(OPTIONAL) Desired reference genome contigs, which are all paths in the GBZ index."
        GIRAFFE_OPTIONS: "(OPTIONAL) extra command line options for Giraffe mapper"
        SPLIT_READ_CORES: "Number of cores to use when splitting the reads into chunks. Default is 8."
        MAP_CORES: "Number of cores to use when mapping the reads. Default is 16."
        MAP_MEM: "Memory, in GB, to use when mapping the reads. Default is 120."
        IN_DIPLOID:"Whether or not to use diploid sampling while doing haplotype sampling. Has to use with Haplotype_sampling=true. Default is 'true'"
        IN_HAPL_FILE: "(OPTIONAL) Path to .hapl file used in haplotype sampling"
        IN_HAPLOTYPE_NUMBER: "Number of generated synthetic haplotypes used in haplotype sampling. (Default: 4)"
    }

    input {
        File INPUT_READ_FILE_1
        File INPUT_READ_FILE_2
        File? INPUT_CRAM_FILE
        File? CRAM_REF
        File? CRAM_REF_INDEX
        File GBZ_FILE
        String SAMPLE_NAME
        Boolean OUTPUT_GAF = false
        Int READS_PER_CHUNK = 20000000
        File? PATH_LIST_FILE
        Array[String]+? CONTIGS
        String GIRAFFE_OPTIONS = ""
        Int SPLIT_READ_CORES = 8
        Int MAP_CORES = 6
        Int MAP_MEM = 120
        Boolean IN_DIPLOID = true
        File? IN_HAPL_FILE
        Int IN_HAPLOTYPE_NUMBER = 4
    }

    if(defined(INPUT_CRAM_FILE) && defined(CRAM_REF) && defined(CRAM_REF_INDEX)) {
	    call utils.convertCRAMtoFASTQ {
            input:
            in_cram_file=INPUT_CRAM_FILE,
            in_ref_file=CRAM_REF,
            in_ref_index_file=CRAM_REF_INDEX,
            in_cores=SPLIT_READ_CORES
	    }
    }

    call hapl.HaplotypeSampling {
        input:
            IN_GBZ_FILE=GBZ_FILE,
            INPUT_READ_FILE_FIRST=INPUT_READ_FILE_1,
            INPUT_READ_FILE_SECOND=INPUT_READ_FILE_2,
            HAPL_FILE=IN_HAPL_FILE,
            CORES=MAP_CORES,
            HAPLOTYPE_NUMBER=IN_HAPLOTYPE_NUMBER,
            DIPLOID=IN_DIPLOID
    }

    File file_gbz = HaplotypeSampling.sampled_graph
    File file_min = HaplotypeSampling.sampled_min
    File file_dist = HaplotypeSampling.sampled_dist

    # Split input reads into chunks for parallelized mapping
    call utils.splitReads as firstReadPair {
        input:
            in_read_file=INPUT_READ_FILE_1,
            in_pair_id="1",
            in_reads_per_chunk=READS_PER_CHUNK,
            in_split_read_cores=SPLIT_READ_CORES
    }

    # Which path names to work on?
    if (!defined(CONTIGS)) {
        if (!defined(PATH_LIST_FILE)) {
            # Extract path names to call against from GBZ file if PATH_LIST_FILE input not provided
            # Filter down to major paths, because GRCh38 includes thousands of
            # decoys aREFERENCE_PREFIX: "Remove this off the beginning of path names in surjected BAM (set to match prefix in PATH_LIST_FILE)"
            # scatter across them, nor do we care about accuracy on them, and also
            # calling on the decoys is semantically meaningless.
            call map.extractSubsetPathNames {
                input:
                    in_gbz_file=file_gbz,
                    in_extract_mem=MAP_MEM
            }
        }
    } 

    if (defined(CONTIGS)) {
        # Put the paths in a file to use later. We know the value is defined,
        # but WDL is a bit low on unboxing calls for optionals so we use
        # select_first.
        File written_path_names_file = write_lines(select_first([CONTIGS]))
    }

    File pipeline_path_list_file = select_first([PATH_LIST_FILE, extractSubsetPathNames.output_path_list_file, written_path_names_file])
    
    ################################################################
    # Distribute vg mapping operation over each chunked read pair #
    ################################################################
    
    call utils.splitReads as secondReadPair {
        input:
        in_read_file=INPUT_READ_FILE_2,
        in_pair_id="2",
        in_reads_per_chunk=READS_PER_CHUNK,
        in_split_read_cores=SPLIT_READ_CORES
    }

    Array[Pair[File,File]] read_pair_chunk_files_list = zip(firstReadPair.output_read_chunks, secondReadPair.output_read_chunks)
    
    scatter (read_pair_chunk_files in read_pair_chunk_files_list) {
        call map.runVGGIRAFFE as runVGGIRAFFEpe {
            input:
                fastq_file_1=read_pair_chunk_files.left,
                fastq_file_2=read_pair_chunk_files.right,
                in_giraffe_options=GIRAFFE_OPTIONS,
                in_gbz_file=file_gbz,
                in_dist_file=file_dist,
                in_min_file=file_min,
                # We always need to pass a full dict file here, with lengths,
                # because if we pass just path lists and the paths are not
                # completely contained in the graph (like if we're working on
                # GRCh38 paths in a CHM13-based graph), giraffe won't be able
                # to get the path lengths and will crash.
                # TODO: Somehow this problem is supposed to go away if we pull
                # any GRCh38. prefix off the path names by setting
                # REFERENCE_PREFIX and making sure the prefix isn't in the
                # truth set.
                # See <https://github.com/adamnovak/giraffe-dv-wdl/pull/2#issuecomment-955096920>
                in_sample_name=SAMPLE_NAME,
                nb_cores=MAP_CORES,
                mem_gb=MAP_MEM
        }
    }

    Array[File] gaf_chunks = runVGGIRAFFEpe.chunk_gaf_file

    call gautils.mergeGAF {
        input:
            in_sample_name=SAMPLE_NAME,
            in_gaf_chunk_files=gaf_chunks
    }
    
    call cal.vg_pack {
        input:
            in_gaf_file = mergeGAF.output_merged_gaf,
            in_gbz_file = GBZ_FILE,
            in_sample_name = SAMPLE_NAME
        }

    call cal.vg_call {
        input:
            in_gbz_file = GBZ_FILE,
            in_pack_file = vg_pack.output_pack,
            paths_list = pipeline_path_list_file,
            in_sample_name = SAMPLE_NAME
        }
    
    output {
        File output_gaf = mergeGAF.output_merged_gaf
        File output_vcf = vg_call.output_call
    }   
}
