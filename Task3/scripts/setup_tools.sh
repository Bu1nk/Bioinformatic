#!/usr/bin/env bash
# Локальная установка инструментов через micromamba (без sudo).
set -euo pipefail

MAMBA_ROOT="${HOME}/micromamba"
ENV_NAME="bioinformatic"
TOOLS_DIR="${HOME}/bioinformatic_tools"
mkdir -p "$TOOLS_DIR"

if [[ ! -x "${MAMBA_ROOT}/bin/micromamba" ]]; then
    echo "Installing micromamba..."
    mkdir -p "${MAMBA_ROOT}"
    cd "${MAMBA_ROOT}"
    curl -Ls "https://micro.mamba.pm/api/micromamba/linux-64/latest" \
        | tar -xvj --strip-components=1 bin/micromamba
fi

export MAMBA_ROOT_PREFIX="${MAMBA_ROOT}"
eval "$("${MAMBA_ROOT}/bin/micromamba" shell hook -s bash -r "${MAMBA_ROOT}")"

micromamba create -y -n "${ENV_NAME}" -c conda-forge -c bioconda \
    bwa samtools fastqc sra-tools freebayes graphviz jq wget curl unzip

micromamba activate "${ENV_NAME}"

# Cromwell (Java)
cd "$TOOLS_DIR"
VER=85
[[ -f cromwell.jar ]] || wget -q -O cromwell.jar \
    "https://github.com/broadinstitute/cromwell/releases/download/${VER}/cromwell-${VER}.jar"
[[ -f womtool.jar ]] || wget -q -O womtool.jar \
    "https://github.com/broadinstitute/cromwell/releases/download/${VER}/womtool-${VER}.jar"

cat > "${TOOLS_DIR}/env.sh" <<EOF
export MAMBA_ROOT_PREFIX="${MAMBA_ROOT}"
eval "\$("${MAMBA_ROOT}/bin/micromamba" shell hook -s bash -r "${MAMBA_ROOT}")"
micromamba activate ${ENV_NAME}
export CROMWELL_JAR="${TOOLS_DIR}/cromwell.jar"
export WOMTOOL_JAR="${TOOLS_DIR}/womtool.jar"
EOF

echo "Environment ready. Source: ${TOOLS_DIR}/env.sh"
source "${TOOLS_DIR}/env.sh"
bwa 2>&1 | head -1 || true
samtools --version | head -1
fastqc --version
fasterq-dump --version 2>&1 | head -1
freebayes --version 2>&1 | head -1 || true
