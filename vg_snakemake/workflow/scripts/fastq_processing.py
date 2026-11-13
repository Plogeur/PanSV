import csv
import argparse


parser = argparse.ArgumentParser(
    description="Generate TSV file with sample, fq1, fq2 filtered by PLINK IID."
)

parser.add_argument(
    "-i", "--input",
    required=True,
    help="Input SRA CSV file"
)

parser.add_argument(
    "-p", "--phenotype",
    required=True,
    help="PLINK phenotype file (must contain IID column)"
)

parser.add_argument(
    "-o", "--output",
    required=True,
    help="Output TSV file"
)

args = parser.parse_args()


# ---- Read IID values from PLINK phenotype file ----
iid_set = set()

with open(args.phenotype, "r", newline="") as pheno_file:
    reader = csv.DictReader(pheno_file, delimiter="\t")

    for row in reader:
        if "IID" in row:
            iid_set.add("DGRP_" + row["IID"].split('_')[1])

# ---- Process SRA file and filter by IID ----
with open(args.input, "r", newline="") as infile, \
     open(args.output, "w", newline="") as outfile:

    reader = csv.DictReader(infile, delimiter=",")
    writer = csv.writer(outfile, delimiter="\t")

    # Write header
    writer.writerow(["sample", "fq1", "fq2"])

    for row in reader:
        run = row["Run"]
        sample = row["strain"]

        # Keep only samples present in IID
        if sample not in iid_set:
            continue

        layout = row["LibraryLayout"]

        if layout == "PAIRED":
            fq1 = f"data/{run}_R1.fastq.gz"
            fq2 = f"data/{run}_R2.fastq.gz"
            writer.writerow([run, fq1, fq2])
        else:  # SINGLE
            fq1 = f"data/{run}.fastq.gz"
            writer.writerow([run, fq1, ""])

# python3 fastq_processing.py -i ../../../../gwas/droso/data/SraRunTable_all.csv -o ../../config/sample_info.tsv -p ../../../../gwas/droso/data/S21_1547_M.pheno.plink2.tsv
