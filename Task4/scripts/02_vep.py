"""Аннотация VCF через Ensembl VEP REST API (GRCh38).

Сохраняет сырой JSON и TSV со всеми транскриптами (одна строка = вариант x транскрипт).
Настройки аннотации записываются в results/vep_settings.txt.
"""
import csv
import json
import time
import urllib.request
from pathlib import Path

VCF = Path("data/student_11.vcf")
RAW = Path("results/raw/vep_rest.json")
TSV = Path("results/raw/vep_all_transcripts.tsv")
SETTINGS = Path("results/vep_settings.txt")

URL = "https://rest.ensembl.org/vep/homo_sapiens/region"
PARAMS = {
    "mane": 1,          # MANE Select / MANE Plus Clinical
    "canonical": 1,     # флаг канонического транскрипта Ensembl
    "hgvs": 1,          # HGVSc / HGVSp
    "protein": 1,       # ID белка
    "numbers": 1,       # номер экзона/интрона
    "variant_class": 1,
    "af_gnomade": 1,    # частоты gnomAD exomes
    "af_gnomadg": 1,    # частоты gnomAD genomes
    "SIFT": "b",
    "PolyPhen": "b",
}
BATCH = 25


def vep_batch(variants):
    query = "&".join(f"{k}={v}" for k, v in PARAMS.items())
    req = urllib.request.Request(
        f"{URL}?{query}",
        data=json.dumps({"variants": variants}).encode(),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )
    for attempt in range(5):
        try:
            return json.load(urllib.request.urlopen(req, timeout=300))
        except Exception as e:  # REST иногда отвечает 500/429 — повторяем
            print(f"  retry {attempt + 1}: {e}")
            time.sleep(5 * (attempt + 1))
    raise RuntimeError("VEP REST failed")


lines = [l.rstrip("\n") for l in VCF.open() if not l.startswith("#")]
variants = [" ".join(l.split("\t")) for l in lines]

result = []
for i in range(0, len(variants), BATCH):
    print(f"VEP: {i + 1}-{min(i + BATCH, len(variants))}")
    result += vep_batch(variants[i:i + BATCH])

RAW.parent.mkdir(parents=True, exist_ok=True)
RAW.write_text(json.dumps(result, indent=1), encoding="utf-8")

cols = ["input", "id", "most_severe_consequence", "gene_symbol", "gene_id", "transcript_id",
        "biotype", "consequence_terms", "impact", "canonical", "mane_select", "mane_plus_clinical",
        "hgvsc", "hgvsp", "amino_acids", "codons", "exon", "intron",
        "sift_prediction", "sift_score", "polyphen_prediction", "polyphen_score"]
with TSV.open("w", newline="", encoding="utf-8") as f:
    w = csv.writer(f, delimiter="\t")
    w.writerow(cols)
    for v in result:
        for t in v.get("transcript_consequences", []):
            w.writerow([
                v["input"].replace(" ", ":"), v.get("id"), v.get("most_severe_consequence"),
                t.get("gene_symbol"), t.get("gene_id"), t.get("transcript_id"), t.get("biotype"),
                ",".join(t.get("consequence_terms", [])), t.get("impact"),
                "YES" if t.get("canonical") else "", t.get("mane_select", ""),
                t.get("mane_plus_clinical", ""), t.get("hgvsc", ""), t.get("hgvsp", ""),
                t.get("amino_acids", ""), t.get("codons", ""), t.get("exon", ""), t.get("intron", ""),
                t.get("sift_prediction", ""), t.get("sift_score", ""),
                t.get("polyphen_prediction", ""), t.get("polyphen_score", ""),
            ])

SETTINGS.write_text(
    "Ensembl VEP REST API\n"
    f"Endpoint: POST {URL}\n"
    f"Ensembl release: {json.load(urllib.request.urlopen(urllib.request.Request('https://rest.ensembl.org/info/data', headers={'Accept': 'application/json'})))['releases']}\n"
    "Species: homo_sapiens, assembly GRCh38\n"
    "Transcript set: Ensembl/GENCODE (все транскрипты, без --pick)\n"
    "Parameters:\n" + "".join(f"  {k}={v}\n" for k, v in PARAMS.items()) +
    "Правило выбора транскрипта для итоговой таблицы:\n"
    "  1) берётся most_severe_consequence варианта по всем транскриптам;\n"
    "  2) среди транскриптов с этим последствием выбирается MANE Select,\n"
    "     если его нет — канонический транскрипт Ensembl, иначе — первый protein_coding;\n"
    "  3) отдельно указывается последствие в MANE Select транскрипте гена.\n",
    encoding="utf-8",
)
print(f"Saved {len(result)} variants -> {RAW}, {TSV}")
