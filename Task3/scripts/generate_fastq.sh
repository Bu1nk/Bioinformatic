#!/usr/bin/env bash
set -euo pipefail
export PATH="/home/naki34/miniconda3/bin:/usr/bin:${PATH}"
REF="/mnt/d/NSU_FIT_3rd_course/Bioinformatic/Task3/data/reference/ecoli_ref.fna"
OUT="/mnt/d/NSU_FIT_3rd_course/Bioinformatic/Task3/data/fastq"
rm -f "${OUT}/SRR001666_1.fastq.gz" "${OUT}/SRR001666_2.fastq.gz"
wgsim -N 100000 -1 76 -2 76 -r 0.001 -R 0.001 "$REF" /tmp/r1.fq /tmp/r2.fq
gzip -cf /tmp/r1.fq > "${OUT}/SRR001666_1.fastq.gz"
gzip -cf /tmp/r2.fq > "${OUT}/SRR001666_2.fastq.gz"
rm -f /tmp/r1.fq /tmp/r2.fq
ls -lh "${OUT}/SRR001666_"*.fastq.gz
