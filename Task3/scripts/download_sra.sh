#!/usr/bin/env bash
# Скачивание ридов E. coli K-12 MG1655 (Illumina paired-end) из NCBI SRA.
# Run: SRR001666 — https://www.ncbi.nlm.nih.gov/sra/SRR001666
#
# Основной способ: ENA HTTPS (зеркало SRA, стабильнее в WSL).
# Альтернатива: fasterq-dump --split-files -X N SRR001666

set -euo pipefail

RUN_ACCESSION="${1:-SRR001666}"
OUT_DIR="${2:-data/fastq}"
MAX_READS="${3:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK3_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_PATH="${TASK3_DIR}/${OUT_DIR}"

mkdir -p "$OUT_PATH"
export PATH="/usr/local/bin:/usr/bin:/bin:/home/naki34/miniconda3/bin:${PATH}"

R1="${OUT_PATH}/${RUN_ACCESSION}_1.fastq.gz"
R2="${OUT_PATH}/${RUN_ACCESSION}_2.fastq.gz"

ENA_BASE="https://ftp.sra.ebi.ac.uk/vol1/fastq"

# Путь ENA для SRR001666: SRR001/SRR001666/
if [[ "$RUN_ACCESSION" == "SRR001666" ]]; then
    ENA_R1="${ENA_BASE}/SRR001/SRR001666/${RUN_ACCESSION}_1.fastq.gz"
    ENA_R2="${ENA_BASE}/SRR001/SRR001666/${RUN_ACCESSION}_2.fastq.gz"
else
    # Общий шаблон: SRRxxx/SRRxxxxxx/
    PREFIX="${RUN_ACCESSION:0:6}"
    ENA_R1="${ENA_BASE}/${PREFIX}/${RUN_ACCESSION}/${RUN_ACCESSION}_1.fastq.gz"
    ENA_R2="${ENA_BASE}/${PREFIX}/${RUN_ACCESSION}/${RUN_ACCESSION}_2.fastq.gz"
fi

echo "SRA run: ${RUN_ACCESSION}"
echo "Output: ${OUT_PATH}"

if [[ ! -s "$R1" ]]; then
    echo "Downloading R1 from ENA..."
    wget -c -O "$R1" "$ENA_R1"
fi
if [[ ! -s "$R2" ]]; then
    echo "Downloading R2 from ENA..."
    wget -c -O "$R2" "$ENA_R2"
fi

if [[ "$MAX_READS" -gt 0 ]] && command -v seqtk &>/dev/null; then
    echo "Subsetting to ${MAX_READS} read pairs..."
    seqtk sample -s42 "$R1" "$MAX_READS" | gzip > "${R1}.sub.gz"
    seqtk sample -s42 "$R2" "$MAX_READS" | gzip > "${R2}.sub.gz"
    mv "${R1}.sub.gz" "$R1"
    mv "${R2}.sub.gz" "$R2"
fi

echo "Done:"
ls -lh "$R1" "$R2"
