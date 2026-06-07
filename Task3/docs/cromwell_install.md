# Установка Cromwell (Classic WDL)

**Фреймворк:** [WDL](https://openwdl.org/) — язык описания пайплайнов.  
**Исполнитель (Classic):** [Cromwell](https://github.com/broadinstitute/cromwell) — движок от Broad Institute, исторически основной рантайм для WDL.

## Требования

- Java 11+ (в WSL: `openjdk-17-jre`)
- Docker (для запуска task-контейнеров) **или** локально установленные `bwa`, `samtools`, `fastqc`, `freebayes`

## Скачивание и установка

```bash
# 1. Java
sudo apt-get update
sudo apt-get install -y default-jre

# 2. Cromwell (последний релиз)
CROMWELL_VERSION=85
wget -O ~/cromwell.jar \
  "https://github.com/broadinstitute/cromwell/releases/download/${CROMWELL_VERSION}/cromwell-${CROMWELL_VERSION}.jar"

# 3. Womtool (валидация WDL и генерация графа DAG)
wget -O ~/womtool.jar \
  "https://github.com/broadinstitute/cromwell/releases/download/${CROMWELL_VERSION}/womtool-${CROMWELL_VERSION}.jar"

# 4. Проверка
java -jar ~/cromwell.jar --version
java -jar ~/womtool.jar --version
```

## Конфигурация (опционально)

Файл `Task3/cromwell/cromwell.conf` в репозитории настроен на локальный запуск без Docker (`Local` backend).

## Hello World

```bash
cd Task3
java -jar ~/cromwell.jar run wdl/hello_world.wdl \
  -i inputs/hello_world.json \
  -o results/cromwell_hello/
```

## Пайплайн оценки качества картирования

```bash
java -jar ~/cromwell.jar run wdl/mapping_qc.wdl \
  -i inputs/mapping_qc.json \
  -o results/cromwell_mapping_qc/
```

## Визуализация DAG

```bash
java -jar ~/womtool.jar graph wdl/mapping_qc.wdl > results/mapping_qc_dag.dot
dot -Tpng results/mapping_qc_dag.dot -o results/mapping_qc_dag.png
```

`womtool graph` строит граф зависимостей **task**-ов WDL (узлы = задачи, рёбра = передача файлов/переменных). Это не блок-схема с ромбами «да/нет» — условный блок `if (mapping_ok)` отображается как отдельная ветка графа, без явных меток OK/not OK на рёбрах.

## Полезные ссылки

- [OpenWDL — Getting Started](https://openwdl.org/)
- [Cromwell documentation](https://cromwell.readthedocs.io/)
- [WDL tutorials (OpenWDL)](https://openwdl.org/docs/)
