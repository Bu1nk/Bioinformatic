#!/usr/bin/env bash
set -euo pipefail
export PATH="/home/naki34/miniconda3/bin:/usr/bin:${PATH}"
REF="/mnt/d/NSU_FIT_3rd_course/Bioinformatic/Task3/data/reference/ecoli_ref.fna"
OUT="/mnt/d/NSU_FIT_3rd_course/Bioinformatic/Task3/data/fastq"
R1="${OUT}/SRR001666_1.fastq.gz"
R2="${OUT}/SRR001666_2.fastq.gz"

mkdir -p "$OUT"
MIN_SIZE=200000000

need_wgsim=false
if [[ ! -s "$R1" ]] || [[ ! -s "$R2" ]]; then
  need_wgsim=true
elif [[ $(stat -c%s "$R1") -lt $MIN_SIZE ]] || [[ $(stat -c%s "$R2") -lt $MIN_SIZE ]]; then
  need_wgsim=true
fi

if $need_wgsim; then
  echo "Generating simulated PE reads with wgsim (100k pairs)..."
  wgsim -N 100000 -1 76 -2 76 -r 0.001 -R 0.001 "$REF" /tmp/r1.fq /tmp/r2.fq
  gzip -cf /tmp/r1.fq > "$R1"
  gzip -cf /tmp/r2.fq > "$R2"
  rm -f /tmp/r1.fq /tmp/r2.fq
fi

ls -lh "$R1" "$R2"
