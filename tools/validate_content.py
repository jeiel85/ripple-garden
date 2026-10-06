#!/usr/bin/env python3
from pathlib import Path
import json, sys

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot" / "data"
errors = []

def load(name):
    p = DATA / name
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        errors.append(f"{name}: parse failed: {e}")
        return []

regions = load("regions.json")
fish = load("fish_catalog.json")
rods = load("rods.json")
baits = load("baits.json")
progression = load("progression.json")

def ids(items, label):
    seen = set()
    for i, item in enumerate(items):
        if not isinstance(item, dict) or not item.get("id"):
            errors.append(f"{label}[{i}]: missing id")
            continue
        if item["id"] in seen:
            errors.append(f"{label}: duplicate id {item['id']}")
        seen.add(item["id"])
    return seen

region_ids = ids(regions, "regions")
fish_ids = ids(fish, "fish")
rod_ids = ids(rods, "rods")
bait_ids = ids(baits, "baits")

for f in fish:
    fid = f.get("id","?")
    if not (1 <= int(f.get("rarity",0)) <= 5):
        errors.append(f"{fid}: rarity outside 1..5")
    if float(f.get("base_weight",0)) <= 0:
        errors.append(f"{fid}: base_weight <= 0")
    size = f.get("size_cm",{})
    if float(size.get("min",0)) <= 0 or float(size.get("max",0)) <= float(size.get("min",0)):
        errors.append(f"{fid}: invalid size range")
    for r in f.get("regions",[]):
        if r not in region_ids:
            errors.append(f"{fid}: missing region {r}")
    if not f.get("habitats"):
        errors.append(f"{fid}: no habitats")
    if not f.get("bait_tags"):
        errors.append(f"{fid}: no bait tags")

if len(fish) != 72:
    errors.append(f"expected 72 fish, found {len(fish)}")

points = progression.get("restoration_points", []) if isinstance(progression, dict) else []
if len(points) != 11 or points[0] != 0 or any(b <= a for a,b in zip(points, points[1:])):
    errors.append("progression: restoration_points must contain 11 strictly increasing values starting at 0")

if errors:
    print("VALIDATION FAILED")
    for e in errors:
        print(" -", e)
    sys.exit(1)

print("VALIDATION OK")
print(f"Regions: {len(regions)}")
print(f"Fish: {len(fish)}")
print(f"Rods: {len(rods)}")
print(f"Baits: {len(baits)}")
