#!/usr/bin/env Rscript

library(argparser)
library(rmarkdown)

p <- arg_parser("Render report")

p <- add_argument(p, "--script", help="script")
p <- add_argument(p, "--output", help="output")
p <- add_argument(p, "--benchmark_dir", help="benchmark_dir")

argv <- parse_args(p)

rmarkdown::render(
  input = argv$script,
  output_file = argv$output,
  knit_root_dir = getwd(),
  params = list(
    benchmark_dir = argv$benchmark_dir
  )
)
