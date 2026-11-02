"""Сборка итоговой таблицы (50 строк) из VEP, ClinVar и gnomAD."""
import csv
import json
from pathlib import Path

VEP = Path("results/raw/vep_rest.json")
CLINVAR = Path("results/raw/clinvar.tsv")
GNOMAD = Path("results/raw/gnomad.tsv")
OUT_TSV = Path("results/annotation_table.tsv")
OUT_XLSX = Path("results/annotation_table.xlsx")

# Порядок тяжести последствий по Ensembl (от самого тяжёлого)
SEVERITY = [
    "transcript_ablation", "splice_acceptor_variant", "splice_donor_variant", "stop_gained",
    "frameshift_variant", "stop_lost", "start_lost", "transcript_amplification",
    "feature_elongation", "feature_truncation", "inframe_insertion", "inframe_deletion",
    "missense_variant", "protein_altering_variant", "splice_donor_5th_base_variant",
    "splice_region_variant", "splice_donor_region_variant", "splice_polypyrimidine_tract_variant",
    "incomplete_terminal_codon_variant", "start_retained_variant", "stop_retained_variant",
    "synonymous_variant", "coding_sequence_variant", "mature_miRNA_variant",
    "5_prime_UTR_variant", "3_prime_UTR_variant", "non_coding_transcript_exon_variant",
    "intron_variant", "NMD_transcript_variant", "non_coding_transcript_variant",
    "coding_transcript_variant", "upstream_gene_variant", "downstream_gene_variant",
    "TFBS_ablation", "TFBS_amplification", "TF_binding_site_variant",
    "regulatory_region_ablation", "regulatory_region_amplification", "regulatory_region_variant",
    "intergenic_variant", "sequence_variant",
]
RANK = {c: i for i, c in enumerate(SEVERITY)}


def worst(terms):
    return min(terms, key=lambda c: RANK.get(c, len(SEVERITY)))


def pick_transcript(transcripts, csq):
    """Транскрипт для most_severe_consequence: MANE Select > canonical > protein_coding."""
    cands = [t for t in transcripts if csq in t.get("consequence_terms", [])]
    for rule, test in (("MANE Select", lambda t: t.get("mane_select")),
                       ("Ensembl canonical", lambda t: t.get("canonical")),
                       ("protein_coding", lambda t: t.get("biotype") == "protein_coding"),
                       ("first", lambda t: True)):
        for t in cands:
            if test(t):
                return t, rule
    return {}, ""


def fmt_af(x):
    return "" if x in ("", None) else f"{float(x):.3g}"


clinvar = {r["variant"]: r for r in csv.DictReader(CLINVAR.open(encoding="utf-8"), delimiter="\t")}
gnomad = {r["variant_id"]: r for r in csv.DictReader(GNOMAD.open(encoding="utf-8"), delimiter="\t")}

rows = []
for v in json.load(VEP.open(encoding="utf-8")):
    chrom, pos, rsid, ref, alt = v["input"].split()[:5]
    tcs = v.get("transcript_consequences", [])
    msc = v.get("most_severe_consequence")
    t, rule = pick_transcript(tcs, msc)
    # MANE Select того же гена; если у гена его нет — MANE Select перекрывающегося гена
    manes = [x for x in tcs if x.get("mane_select")]
    mane = next((x for x in manes if x.get("gene_symbol") == t.get("gene_symbol")), manes[0] if manes else {})
    genes = sorted({x.get("gene_symbol") for x in tcs if x.get("gene_symbol")})
    cv = clinvar[f"{chrom}:{pos}:{ref}>{alt}"]
    gn = gnomad[f"{chrom}-{pos}-{ref}-{alt}"]
    rows.append({
        "variant": f"chr{chrom}:{pos} {ref}>{alt}",
        "rsID": rsid,
        "gene": t.get("gene_symbol", ""),
        "all_genes": ",".join(genes),
        "most_severe_consequence": msc,
        "impact": t.get("impact", ""),
        "transcript": t.get("transcript_id", ""),
        "transcript_rule": rule,
        "HGVSc": t.get("hgvsc", ""),
        "HGVSp": t.get("hgvsp", ""),
        "MANE_Select_RefSeq": f"{mane.get('gene_symbol')}:{mane['mane_select']}" if mane else "",
        "MANE_consequence": worst(mane["consequence_terms"]) if mane else "",
        "SIFT": t.get("sift_prediction", ""),
        "PolyPhen": t.get("polyphen_prediction", ""),
        "n_transcripts": len(tcs),
        "gnomAD_AF": fmt_af(gn.get("af_joint")),
        "gnomAD_AF_exome": fmt_af(gn.get("af_exome")),
        "gnomAD_AF_genome": fmt_af(gn.get("af_genome")),
        "gnomAD_popmax": f"{gn['popmax_population']} {fmt_af(gn['popmax_af'])}" if gn.get("popmax_population") else "",
        "gnomAD_homozygotes": gn.get("homozygotes_joint", ""),
        "ClinVar_present": cv["clinvar_present"],
        "ClinVar_accession": cv["clinvar_accession"],
        "ClinVar_classification": cv["classification"],
        "ClinVar_review_status": cv["review_status"],
        "ClinVar_conditions": cv["conditions"],
    })

OUT_TSV.parent.mkdir(parents=True, exist_ok=True)
with OUT_TSV.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]), delimiter="\t")
    w.writeheader()
    w.writerows(rows)

try:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill
    wb = Workbook()
    ws = wb.active
    ws.title = "student_11"
    ws.append(list(rows[0]))
    for r in rows:
        ws.append(list(r.values()))
    for c in ws[1]:
        c.font = Font(bold=True)
        c.fill = PatternFill("solid", fgColor="DDEBF7")
    for col in ws.columns:
        width = max(len(str(c.value or "")) for c in col)
        ws.column_dimensions[col[0].column_letter].width = min(max(width + 2, 10), 50)
    ws.freeze_panes = "C2"
    ws.auto_filter.ref = ws.dimensions
    wb.save(OUT_XLSX)
except ImportError:
    print("openpyxl not installed — XLSX skipped")

print(f"{len(rows)} rows -> {OUT_TSV}")
