#!/usr/bin/env bash
# Полный прогон Task3 в WSL.
set -euo pipefail

TASK3="/mnt/d/NSU_FIT_3rd_course/Bioinformatic/Task3"
export PATH="/usr/local/bin:/usr/bin:/bin:/home/naki34/miniconda3/bin:${PATH}"

cd "$TASK3"

echo "=== 1. Tools ==="
for cmd in bwa samtools fastqc fasterq-dump freebayes dot java; do
  command -v "$cmd" >/dev/null || { echo "Missing: $cmd"; exit 1; }
done

echo "=== 2. Reference ==="
REF="$TASK3/data/reference/ecoli_ref.fna"
[[ -s "$REF" ]] || wget -q -O "$REF" \
  'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_000913.3&rettype=fasta&retmode=text'

echo "=== 3. SRA download (subset) ==="
R1="$TASK3/data/fastq/SRR001666_1.fastq.gz"
R2="$TASK3/data/fastq/SRR001666_2.fastq.gz"
if [[ ! -s "$R1" ]]; then
  bash "$TASK3/scripts/download_sra.sh" SRR001666 data/fastq 200000
fi

echo "=== 4. Bash pipeline ==="
bash "$TASK3/scripts/mapping_qc.sh" \
  "$REF" "$R1" "$R2" \
  "$TASK3/results/bash_pipeline" SRR001666

echo "=== 5. Cromwell ==="
TOOLS="/home/naki34/bioinformatic_tools"
mkdir -p "$TOOLS"
[[ -f "$TOOLS/cromwell.jar" ]] || wget -q -O "$TOOLS/cromwell.jar" \
  https://github.com/broadinstitute/cromwell/releases/download/85/cromwell-85.jar
[[ -f "$TOOLS/womtool.jar" ]] || wget -q -O "$TOOLS/womtool.jar" \
  https://github.com/broadinstitute/cromwell/releases/download/85/womtool-85.jar

echo "=== 6. Hello World WDL ==="
java -jar "$TOOLS/cromwell.jar" run wdl/hello_world.wdl \
  -i inputs/hello_world.json \
  -o results/cromwell_hello 2>&1 | tee results/cromwell_hello/run.log

echo "=== 7. Mapping QC WDL ==="
java -jar "$TOOLS/cromwell.jar" run wdl/mapping_qc.wdl \
  -i inputs/mapping_qc.json \
  -o results/cromwell_mapping_qc 2>&1 | tee results/cromwell_mapping_qc/run.log

echo "=== 8. DAG visualization ==="
java -jar "$TOOLS/womtool.jar" graph wdl/mapping_qc.wdl > results/mapping_qc_dag.dot
dot -Tpng results/mapping_qc_dag.dot -o results/mapping_qc_dag.png

echo "=== Done ==="
