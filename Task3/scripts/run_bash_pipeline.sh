#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
TASK3="$(cd "$(dirname "$0")/.." && pwd)"
bash "${TASK3}/scripts/mapping_qc.sh" \
  "${TASK3}/data/reference/ecoli_ref.fna" \
  "${TASK3}/data/fastq/SRR001666_1.fastq.gz" \
  "${TASK3}/data/fastq/SRR001666_2.fastq.gz" \
  "${TASK3}/results/bash_pipeline" \
  SRR001666
