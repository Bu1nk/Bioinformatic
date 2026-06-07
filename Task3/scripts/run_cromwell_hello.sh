#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
TASK3="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK3"
mkdir -p results/cromwell_hello
java -jar "$CROMWELL_JAR" run wdl/hello_world.wdl \
  -i inputs/hello_world.json \
  2>&1 | tee results/cromwell_hello/run.log
