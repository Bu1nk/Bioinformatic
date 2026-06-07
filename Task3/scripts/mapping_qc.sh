#!/usr/bin/env bash
# Алгоритм оценки качества картирования (bash).
# Соответствует блок-схеме задания: FastQC -> bwa mem -> samtools view ->
# flagstat -> parse %mapped -> OK/not OK -> [sort + freebayes при OK].
#
# Использование:
#   mapping_qc.sh <ref.fa> <R1.fastq.gz> <R2.fastq.gz> <output_dir> [sample_name]
#
# Требует: fastqc, bwa, samtools, freebayes (опционально для коллинга).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSE_SCRIPT="${SCRIPT_DIR}/parse_flagstat.sh"
MAPPED_THRESHOLD=90

usage() {
    echo "Usage: $0 <ref.fa> <R1.fastq.gz> <R2.fastq.gz> <output_dir> [sample_name]" >&2
    exit 1
}

[[ $# -ge 4 ]] || usage

REF="$1"
R1="$2"
R2="$3"
OUT_DIR="$4"
SAMPLE="${5:-sample}"

mkdir -p "$OUT_DIR"
WORK_DIR="${OUT_DIR}/${SAMPLE}"
mkdir -p "$WORK_DIR"

LOG_FILE="${OUT_DIR}/${SAMPLE}_pipeline.log"
RESULT_FILE="${OUT_DIR}/${SAMPLE}_qc_result.txt"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Mapping QC pipeline: ${SAMPLE} ==="
echo "Started: $(date -Iseconds)"

for cmd in fastqc bwa samtools; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd not found in PATH" >&2
        exit 1
    fi
done

export PATH="/usr/local/bin:/usr/bin:/bin:/home/naki34/miniconda3/bin:${PATH}"

# --- Индекс референса (если ещё не создан) ---
if [[ ! -f "${REF}.bwt" ]]; then
    echo "[1/7] Indexing reference: $REF"
    bwa index "$REF"
else
    echo "[1/7] Reference index exists, skipping bwa index"
fi

# --- FastQC ---
echo "[2/7] FastQC"
FASTQC_DIR="${WORK_DIR}/fastqc"
mkdir -p "$FASTQC_DIR"
fastqc -o "$FASTQC_DIR" -t 2 "$R1" "$R2"

# --- BWA mem ---
echo "[3/7] bwa mem alignment"
SAM="${WORK_DIR}/${SAMPLE}.sam"
bwa mem -t 4 "$REF" "$R1" "$R2" > "$SAM"

# --- SAM -> BAM ---
echo "[4/7] samtools view (SAM -> BAM)"
BAM="${WORK_DIR}/${SAMPLE}.bam"
samtools view -@ 2 -bS "$SAM" -o "$BAM"
rm -f "$SAM"

# --- flagstat ---
echo "[5/7] samtools flagstat"
FLAGSTAT="${WORK_DIR}/${SAMPLE}.flagstat.txt"
samtools flagstat "$BAM" > "$FLAGSTAT"
cp "$FLAGSTAT" "${OUT_DIR}/${SAMPLE}.flagstat.txt"

# --- Parse % mapped ---
echo "[6/7] Parsing mapped percentage"
MAPPED_PCT=$("$PARSE_SCRIPT" "$FLAGSTAT")
echo "Mapped reads: ${MAPPED_PCT}%"

QC_STATUS="not OK"
VARIANT_STEP="skipped (mapping quality below threshold)"

if awk -v p="$MAPPED_PCT" -v t="$MAPPED_THRESHOLD" 'BEGIN { exit !(p > t) }'; then
    QC_STATUS="OK"
    echo "Mapping quality: OK (>${MAPPED_THRESHOLD}%)"

    echo "[7/7] samtools sort + freebayes variant calling"
    SORTED_BAM="${WORK_DIR}/${SAMPLE}.sorted.bam"
    samtools sort -@ 2 -o "$SORTED_BAM" "$BAM"
    samtools index "$SORTED_BAM"

    VCF="${WORK_DIR}/${SAMPLE}.vcf"
    if command -v freebayes &>/dev/null; then
        freebayes -f "$REF" "$SORTED_BAM" > "$VCF"
        VARIANT_STEP="VCF written: $VCF"
    else
        VARIANT_STEP="freebayes not installed — variant calling skipped"
        echo "Warning: freebayes not found, skipping VCF generation"
    fi
else
    echo "Mapping quality: not OK (<=${MAPPED_THRESHOLD}%)"
    echo "[7/7] Skipping sort and variant calling"
fi

# --- Сохранение QC-отчёта ---
QC_REPORT="${OUT_DIR}/${SAMPLE}_fastqc_report"
mkdir -p "$QC_REPORT"
cp -r "${FASTQC_DIR}"/*_fastqc.html "${FASTQC_DIR}"/*_fastqc.zip "$QC_REPORT/" 2>/dev/null || true

{
    echo "Sample: $SAMPLE"
    echo "Reference: $REF"
    echo "R1: $R1"
    echo "R2: $R2"
    echo "Mapped percent: ${MAPPED_PCT}%"
    echo "Threshold: >${MAPPED_THRESHOLD}%"
    echo "Status: $QC_STATUS"
    echo "Flagstat file: ${OUT_DIR}/${SAMPLE}.flagstat.txt"
    echo "Variant calling: $VARIANT_STEP"
    echo "Finished: $(date -Iseconds)"
} > "$RESULT_FILE"

echo "=== Finished: $QC_STATUS ==="
echo "Results: $RESULT_FILE"

if [[ "$QC_STATUS" == "OK" ]]; then
    exit 0
else
    exit 2
fi
