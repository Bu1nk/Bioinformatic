# Задание 4. Клиническая аннотация генетических вариантов

**Студент:** Абрамкин Никита, группа 23213
**Вариант:** `student_11.vcf` (50 SNV, GRCh38)

Отчёт с разбором трёх вариантов и заключением: [report.md](report.md)

## 1. Исходные данные

[data/student_11.vcf](data/student_11.vcf): 50 однонуклеотидных вариантов на chr21 и chr22, координаты в GRCh38.

## 2. Структура VCF

Колонки: `CHROM POS ID REF ALT QUAL FILTER INFO`. В этом файле заполнены только первые пять: хромосома, позиция, rsID, референсный и альтернативный аллели. QUAL, FILTER и INFO стоят как `.`.

Статистика ([results/vcf_stats.txt](results/vcf_stats.txt), скрипт `scripts/01_vcf_stats.py`):

| Параметр | Значение |
|---|---|
| Всего записей | 50 |
| Вариантов на chr21 | 11 |
| Вариантов на chr22 | 39 |
| Транзиции (A↔G, C↔T) | 40 |
| Трансверсии | 10 |
| Ts/Tv | 4.0 |

## 3. Аннотация

| Источник | Как получено | Результат |
|---|---|---|
| Ensembl VEP (release 116) | REST API `POST /vep/homo_sapiens/region`, все транскрипты, MANE, canonical, HGVS, SIFT, PolyPhen, частоты gnomAD | `results/raw/vep_rest.json`, `results/raw/vep_all_transcripts.tsv` (все транскрипты), настройки: [results/vep_settings.txt](results/vep_settings.txt) |
| Ensembl VEP (веб) | https://www.ensembl.org/Tools/VEP (release 116), загрузка VCF через форму | `results/vep_web/vep_web_results.txt` и `.vcf` (экспорт, 1625 строк вариант × транскрипт), скриншоты настроек `settings_01-08.jpg`, сводка `results_summary.jpg`. Командная строка VEP записана в заголовке `vep_web_results.vcf` (`##VEP-command-line`) |
| ClinVar | NCBI E-utilities: поиск по `chr[chr] AND pos[chrpos38]`, затем фильтр по совпадению ALT через canonical SPDI | `results/raw/clinvar_raw.json`, `results/raw/clinvar.tsv`, отдельно `results/raw/clinvar_VCV95167.xml` (все заявки по конфликтному варианту) |
| gnomAD v4.1 | GraphQL API `gnomad.broadinstitute.org/api`, dataset `gnomad_r4`, exomes + genomes | `results/raw/gnomad_raw.json`, `results/raw/gnomad.tsv` |

Результаты веб-версии VEP и REST API совпадают: последствия в MANE Select транскриптах одинаковы для всех 50 вариантов. Различие одно: для rs114565111 (GAL3ST1) колонка CLIN_SIG в VEP пустая, а прямой запрос к ClinVar находит запись VCV004261361 (Uncertain significance). Вероятная причина различия: версии данных ClinVar и кэша VEP 116. Поэтому ClinVar проверялся отдельно.

Одному варианту соответствует много транскриптов (от 3 до 72) с разными последствиями, поэтому в сыром TSV от VEP одна строка: это пара «вариант × транскрипт».

## 4. Итоговая таблица

[results/annotation_table.tsv](results/annotation_table.tsv) / [results/annotation_table.xlsx](results/annotation_table.xlsx): 50 строк, по одной на исходный вариант.

Основные поля:
- `variant`: координаты REF>ALT;
- `rsID`;
- `gene`;
- `most_severe_consequence`, `transcript`, `transcript_rule`: самое значимое последствие по VEP, транскрипт и правило его выбора;
- `MANE_Select_RefSeq`, `MANE_consequence`: последствие в MANE Select транскрипте;
- `SIFT`, `PolyPhen`;
- `gnomAD_AF` (exomes+genomes), `gnomAD_popmax`;
- `ClinVar_present`, `ClinVar_classification`, `ClinVar_review_status`, `ClinVar_conditions`.

**Правило выбора транскрипта.** Берётся самое тяжёлое последствие варианта по всем транскриптам (порядок тяжести Ensembl). Среди транскриптов с этим последствием выбирается MANE Select, если его нет: канонический транскрипт Ensembl, затем любой protein_coding. Так получилось для 42 вариантов из 50 (MANE Select), для 5 (protein_coding) и для 3 (первый транскрипт с этим последствием). Поскольку самое тяжёлое последствие часто приходится на редкий альтернативный транскрипт, рядом всегда указано последствие в MANE Select.

Кратко по итогам:
- в ClinVar есть 26 из 50 вариантов, патогенных среди них нет;
- 2 варианта с неясной значимостью (VUS) и 2 с конфликтом интерпретаций;
- в gnomAD есть все 50 вариантов.

## 5-6. Разбор вариантов и заключение

См. [report.md](report.md).

## Запуск

```bash
cd Task4
python scripts/01_vcf_stats.py
python scripts/02_vep.py
python scripts/03_clinvar.py
python scripts/04_gnomad.py
python scripts/05_build_table.py
```

Нужен Python 3.10+, для XLSX: `openpyxl`. Все запросы идут к публичным API (Ensembl REST, NCBI E-utilities, gnomAD GraphQL), ключи не нужны.

## Ссылки

- Ensembl VEP: https://www.ensembl.org/Tools/VEP
- ClinVar: https://www.ncbi.nlm.nih.gov/clinvar/
- gnomAD: https://gnomad.broadinstitute.org/
- MANE: https://www.ncbi.nlm.nih.gov/refseq/MANE/
