"""Статистика по VCF: число записей, варианты на chr21/chr22, транзиции/трансверсии."""
import sys
from collections import Counter
from pathlib import Path

TRANSITIONS = {frozenset("AG"), frozenset("CT")}

vcf = Path(sys.argv[1] if len(sys.argv) > 1 else "data/student_11.vcf")
out = Path(sys.argv[2] if len(sys.argv) > 2 else "results/vcf_stats.txt")

records = [l.rstrip("\n").split("\t") for l in vcf.open() if not l.startswith("#")]
chroms = Counter(r[0] for r in records)
subs = Counter(f"{r[3]}>{r[4]}" for r in records)
ts = sum(1 for r in records if frozenset(r[3] + r[4]) in TRANSITIONS)
tv = len(records) - ts

lines = [
    f"Файл: {vcf.name}",
    f"Всего записей: {len(records)}",
    f"Вариантов на chr21: {chroms.get('21', 0)}",
    f"Вариантов на chr22: {chroms.get('22', 0)}",
    f"Транзиций (A<->G, C<->T): {ts}",
    f"Трансверсий: {tv}",
    f"Ts/Tv: {ts / tv:.2f}" if tv else "Ts/Tv: -",
    "",
    "Замены REF>ALT:",
    *[f"  {k}: {v}" for k, v in sorted(subs.items())],
]
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))
