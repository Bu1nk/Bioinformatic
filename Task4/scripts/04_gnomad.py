"""Частоты аллелей из gnomAD v4 (GRCh38) через GraphQL API.

Сырые ответы — results/raw/gnomad_raw.json, таблица — results/raw/gnomad.tsv.
"""
import csv
import json
import time
import urllib.request
from pathlib import Path

VCF = Path("data/student_11.vcf")
RAW = Path("results/raw/gnomad_raw.json")
TSV = Path("results/raw/gnomad.tsv")
API = "https://gnomad.broadinstitute.org/api"
DATASET = "gnomad_r4"

QUERY = """
query($id: String!, $ds: DatasetId!) {
  variant(variantId: $id, dataset: $ds) {
    variant_id
    rsids
    exome  { ac an af homozygote_count populations { id ac an } }
    genome { ac an af homozygote_count populations { id ac an } }
    joint  { ac an homozygote_count }
  }
}"""


def gql(variant_id):
    body = json.dumps({"query": QUERY, "variables": {"id": variant_id, "ds": DATASET}}).encode()
    req = urllib.request.Request(API, data=body, headers={"Content-Type": "application/json"})
    for attempt in range(6):
        try:
            return json.load(urllib.request.urlopen(req, timeout=60))
        except urllib.error.HTTPError as e:
            if e.code in (400, 404):  # вариант отсутствует — API вернёт ошибку в теле
                return json.loads(e.read())
            print(f"  retry {attempt + 1}: {e}")
        except Exception as e:
            print(f"  retry {attempt + 1}: {e}")
        time.sleep(5 * (attempt + 1))
    raise RuntimeError(variant_id)


def ratio(ac, an):
    return ac / an if an else None


records = [l.rstrip("\n").split("\t") for l in VCF.open() if not l.startswith("#")]
raw, rows = {}, []
for chrom, pos, rsid, ref, alt, *_ in records:
    vid = f"{chrom}-{pos}-{ref}-{alt}"
    resp = gql(vid)
    raw[vid] = resp
    v = (resp.get("data") or {}).get("variant")
    if v:
        ex, gn, jt = v.get("exome") or {}, v.get("genome") or {}, v.get("joint") or {}
        # максимальная частота среди популяций (exome+genome суммарно)
        pops = {}
        for part in (ex, gn):
            for p in part.get("populations") or []:
                if "_" in p["id"] or p["id"] in ("XX", "XY"):
                    continue  # пропускаем разбивку по полу
                a = pops.setdefault(p["id"], [0, 0])
                a[0] += p["ac"]; a[1] += p["an"]
        popmax = max(((k, ratio(*a)) for k, a in pops.items() if a[1] > 1000),
                     key=lambda x: x[1] or 0, default=(None, None))
        rows.append({
            "variant_id": vid, "rsid": rsid, "gnomad_present": "yes",
            "af_exome": ex.get("af"), "af_genome": gn.get("af"),
            "ac_joint": jt.get("ac"), "an_joint": jt.get("an"),
            "af_joint": ratio(jt.get("ac", 0), jt.get("an", 0)),
            "homozygotes_joint": jt.get("homozygote_count"),
            "popmax_population": popmax[0], "popmax_af": popmax[1],
        })
    else:
        rows.append({"variant_id": vid, "rsid": rsid, "gnomad_present": "no"})
    print(vid, rows[-1].get("af_joint"))
    time.sleep(1)  # gnomAD ограничивает частоту запросов

RAW.parent.mkdir(parents=True, exist_ok=True)
RAW.write_text(json.dumps(raw, indent=1), encoding="utf-8")
fields = ["variant_id", "rsid", "gnomad_present", "af_exome", "af_genome", "ac_joint", "an_joint",
          "af_joint", "homozygotes_joint", "popmax_population", "popmax_af"]
with TSV.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    w.writeheader()
    w.writerows(rows)
print(f"Saved -> {RAW}, {TSV}")
