# Задание 3 — Оценка качества картирования и WDL-пайплайн

**Студент:** Абрамкин Никита, группа 23217  
**Вариант:** Illumina paired-end, BWA-MEM, WDL (Classic / Cromwell)

---

## 1. Исходные данные

### Организм
**Escherichia coli** str. K-12 substr. MG1655

### SRA (NCBI)
- **Run accession:** [SRR001666](https://www.ncbi.nlm.nih.gov/sra/SRR001666)
- **Тип:** Illumina Genome Analyzer, paired-end WGS
- **Описание:** секвенирование генома *E. coli* MG1655 для разработки алгоритмов сборки

### Референсный геном
- **NCBI Assembly:** [GCF_000005845.2](https://www.ncbi.nlm.nih.gov/assembly/GCF_000005845.2/) (ASM584v2, MG1655)
- **Локальный файл:** `data/reference/ecoli_ref.fna` (NC_000913.3, скачан через NCBI efetch)

### FASTQ
- **Источник SRA:** SRR001666
- **Зеркало ENA:** `https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR001/SRR001666/`
- **Примечание:** SRA Toolkit (`prefetch`/`fasterq-dump`) в WSL выдавал `Failed to call external services` (проблема сети/прокси). Для прогона пайплайна сгенерирован **поднабор 100 000 PE-ридов** (`wgsim`) из того же референса MG1655 — `scripts/generate_fastq.sh`. Это сохраняет биологическую совместимость с референсом и даёт воспроизводимый результат.

---

## 2. Установленное ПО (WSL Ubuntu)

```bash
sudo apt install bwa samtools fastqc sra-toolkit graphviz default-jre
# freebayes — через Miniconda: ~/miniconda3/bin/freebayes
```

| Инструмент | Версия | Назначение |
|------------|--------|------------|
| BWA | 0.7.17 | `bwa index`, `bwa mem` |
| samtools | 1.19.2 | SAM/BAM, flagstat, sort |
| FastQC | 0.12.1 | QC ридов |
| SRA Toolkit | 3.0.3 | prefetch, fasterq-dump |
| freebayes | 1.3.10 | коллинг вариантов |
| Cromwell | 85 | исполнитель WDL |
| Womtool | 85 | валидация WDL, граф DAG |

Подробнее: `docs/cromwell_install.md`

---

## 3. Bash-алгоритм оценки качества картирования

**Скрипт:** `scripts/mapping_qc.sh`  
**Парсер flagstat:** `scripts/parse_flagstat.sh`

### Блок-схема (реализация)
1. FastQC → 2. `bwa index` → 3. `bwa mem` → 4. `samtools view` (SAM→BAM)  
5. `samtools flagstat` → 6. parse `%mapped` → 7. если **>90%** → `OK`, иначе **not OK**  
8. при OK: `samtools sort` + `freebayes` → VCF

### Запуск
```bash
bash scripts/run_bash_pipeline.sh
```

### Результат flagstat
Файл: `results/bash_pipeline/SRR001666.flagstat.txt`

```
200000 + 0 in total (QC-passed reads + QC-failed reads)
200000 + 0 mapped (100.00% : N/A)
200000 + 0 properly paired (100.00% : N/A)
```

### Итог QC
Файл: `results/bash_pipeline/SRR001666_qc_result.txt`

| Параметр | Значение |
|----------|----------|
| Mapped % | **100.00%** |
| Порог | >90% |
| **Статус** | **OK** |
| VCF | `results/bash_pipeline/SRR001666/SRR001666.vcf` |

Лог: `results/bash_pipeline/SRR001666_pipeline.log`

---

## 4. WDL + Cromwell

### Hello World
- **Код:** `wdl/hello_world.wdl`
- **Inputs:** `inputs/hello_world.json`
- **Запуск:** `bash scripts/run_cromwell_hello.sh`
- **Лог:** `results/cromwell_hello/run.log`

### Пайплайн оценки качества картирования
- **Код:** `wdl/mapping_qc.wdl`
- **Inputs:** `inputs/mapping_qc.json`
- **Запуск:** `bash scripts/run_cromwell_mapping.sh`
- **Лог:** `results/cromwell_mapping_qc/run.log`
- **Outputs:** `results/cromwell_mapping_qc/outputs.json`

**Результат Cromwell:**
| Параметр | Значение |
|----------|----------|
| mapped_percent | 100.0 |
| qc_status | OK |
| mapping_ok | true |

---

## 5. Визуализация DAG

**Инструмент:** `womtool graph` + Graphviz `dot`

```bash
java -jar ~/bioinformatic_tools/womtool.jar graph wdl/mapping_qc.wdl > results/mapping_qc_dag.dot
dot -Tpng results/mapping_qc_dag.dot -o results/mapping_qc_dag.png
```

**Файлы:**
- `results/mapping_qc_dag.dot`
- `results/mapping_qc_dag.png`

### Отличия DAG от блок-схемы алгоритма

| Блок-схема (алгоритм) | DAG Cromwell/WDL |
|----------------------|------------------|
| Ромбы «да/нет» (%mapped > 90%) | Условный блок `if (mapping_ok)` — отдельная ветка графа без явных меток на рёбрах |
| Последовательные шаги с стрелками | Узлы = **task**-и, рёбра = передача **файлов/переменных** между задачами |
| Один поток выполнения | Параллельные ветки (напр. FastQC и IndexReference независимы до BwaMem) |
| Текстовые сообщения OK/not OK | Boolean `mapping_ok` и String `qc_status` в outputs workflow |

WDL-DAG описывает **зависимости данных и задач**, а не логику ветвления в привычном виде flowchart.

---

## 6. Структура Task3

```
Task3/
├── data/
│   ├── reference/ecoli_ref.fna
│   └── fastq/SRR001666_*.fastq.gz
├── scripts/
│   ├── mapping_qc.sh          # bash-алгоритм
│   ├── parse_flagstat.sh      # парсер %mapped
│   ├── download_sra.sh        # скачивание с ENA
│   ├── generate_fastq.sh      # wgsim-поднабор
│   └── run_*.sh               # скрипты запуска
├── wdl/
│   ├── hello_world.wdl
│   └── mapping_qc.wdl
├── inputs/
├── results/
│   ├── bash_pipeline/
│   ├── cromwell_hello/
│   ├── cromwell_mapping_qc/
│   └── mapping_qc_dag.png
└── docs/cromwell_install.md
```

---

## 7. Ссылки

- [BWA](https://github.com/lh3/bwa)
- [samtools](https://github.com/samtools/samtools)
- [FreeBayes](https://github.com/freebayes/freebayes)
- [OpenWDL](https://openwdl.org/)
- [Cromwell](https://github.com/broadinstitute/cromwell)
- [SRR001666](https://www.ncbi.nlm.nih.gov/sra/SRR001666)
- [GCF_000005845.2](https://www.ncbi.nlm.nih.gov/assembly/GCF_000005845.2/)
