#!/usr/bin/env python3

import argparse
import gzip
import sys

def merge_gaf_files(input_files):
    for file_path in input_files:
        with gzip.open(file_path, "rt") as f:
            for line in f:
                sys.stdout.write(line)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Merge multiple .gaf.gz files and write combined content to stdout."
    )

    parser.add_argument(
        "-i",
        "--input_files",
        nargs="+",
        required=True,
        help="Input .gaf.gz files"
    )

    args = parser.parse_args()
    merge_gaf_files(args.input_files)
