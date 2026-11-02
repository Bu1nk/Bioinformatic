"""Поиск вариантов в ClinVar через NCBI E-utilities.

Ищем по точной позиции GRCh38 (chr + chrpos38), затем оставляем только записи
с тем же ALT-аллелем (по canonical SPDI). Сырые ответы — results/raw/clinvar_raw.json.
"""
import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

VCF = Path("data/student_11.vcf")
RAW = Path("results/raw/clinvar_raw.json")
TSV = Path("results/raw/clinvar.tsv")
EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"


def get(url):
    for attempt in range(5):
        try:
            return json.load(urllib.request.urlopen(url, timeout=60))
        except Exception as e:
            print(f"  retry {attempt + 1}: {e}")
            time.sleep(3 * (attempt + 1))
    raise RuntimeError(url)


records = [l.rstrip("\n").split("\t") for l in VCF.open() if not l.startswith("#")]
raw, rows = {}, []
for chrom, pos, rsid, ref, alt, *_ in records:
    term = f"{chrom}[chr] AND {pos}[chrpos38]"
    search = get(f"{EUTILS}/esearch.fcgi?db=clinvar&retmode=json&term={urllib.parse.quote(term)}")
    ids = search["esearchresult"]["idlist"]
    time.sleep(0.4)  # лимит NCBI без API-ключа: 3 запроса/с
    summary = get(f"{EUTILS}/esummary.fcgi?db=clinvar&retmode=json&id={','.join(ids)}") if ids else {}
    time.sleep(0.4)
    key = f"{chrom}:{pos}:{ref}>{alt}"
    raw[key] = {"term": term, "esearch": search, "esummary": summary}

    matched = []
    for uid in ids:
        doc = summary["result"][uid]
        spdis = [vs.get("canonical_spdi", "") for vs in doc.get("variation_set", [])]
        if not any(s.endswith(f":{ref}:{alt}") for s in spdis):
            continue  # другая замена в той же позиции
        cls = doc.get("germline_classification", {})
        traits = sorted({t["trait_name"] for t in cls.get("trait_set", [])})
        matched.append({
            "uid": uid,
            "accession": doc.get("accession"),
            "title": doc.get("title"),
            "classification": cls.get("description", ""),
            "review_status": cls.get("review_status", ""),
            "last_evaluated": cls.get("last_evaluated", ""),
            "conditions": "; ".join(traits),
        })
    rows.append({
        "variant": key, "rsid": rsid, "clinvar_present": "yes" if matched else "no",
        "clinvar_accession": ",".join(m["accession"] for m in matched),
        "clinvar_uid": ",".join(m["uid"] for m in matched),
        "classification": " | ".join(m["classification"] for m in matched),
        "review_status": " | ".join(m["review_status"] for m in matched),
        "conditions": " | ".join(m["conditions"] for m in matched),
        "title": " | ".join(m["title"] for m in matched),
    })
    print(key, rows[-1]["classification"] or "-")

RAW.parent.mkdir(parents=True, exist_ok=True)
RAW.write_text(json.dumps(raw, indent=1, ensure_ascii=False), encoding="utf-8")
with TSV.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]), delimiter="\t")
    w.writeheader()
    w.writerows(rows)
print(f"Saved -> {RAW}, {TSV}")
