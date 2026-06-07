#!/usr/bin/env bash
# Разбор samtools flagstat: извлечение процента картированных ридов.
# Использование: parse_flagstat.sh <flagstat.txt>
# Вывод: одно число (процент mapped) в stdout; при ошибке — код 1.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <flagstat.txt>" >&2
    exit 1
fi

FLAGSTAT_FILE="$1"

if [[ ! -f "$FLAGSTAT_FILE" ]]; then
    echo "Error: file not found: $FLAGSTAT_FILE" >&2
    exit 1
fi

# Строка вида: "1097662 + 0 mapped (99.83% : N/A)"
MAPPED_LINE=$(grep -E ' mapped \(' "$FLAGSTAT_FILE" | head -n 1)

if [[ -z "$MAPPED_LINE" ]]; then
    echo "Error: 'mapped' line not found in $FLAGSTAT_FILE" >&2
    exit 1
fi

PERCENT=$(echo "$MAPPED_LINE" | sed -n 's/.*(\([0-9.]*\)%.*/\1/p')

if [[ -z "$PERCENT" ]]; then
    echo "Error: could not parse mapped percentage" >&2
    exit 1
fi

echo "$PERCENT"
