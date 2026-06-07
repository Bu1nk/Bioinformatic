#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
TASK3="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK3"
mkdir -p results/cromwell_mapping_qc
java -jar "$CROMWELL_JAR" run wdl/mapping_qc.wdl \
  -i inputs/mapping_qc.json \
  2>&1 | tee results/cromwell_mapping_qc/run.log
