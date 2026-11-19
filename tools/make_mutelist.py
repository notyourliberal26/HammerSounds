"""Build MuteList.lua: stock player-side weapon HIT sound file IDs, grouped by HammerSounds weapon key.

Source: wowdev community listfile lines "id;sound/item/weapons/<folder>/<file>".
NPC variants (files with "npc" in the name) are left out so enemy hits sound normal.
Swing whooshes, bow pull/release and gun fire/load are left out: only impacts are muted.
"""
import re, sys
from collections import OrderedDict

listfile, out = sys.argv[1], sys.argv[2]

# weapon key -> (folders, optional filename regex that must match)
GROUPS = OrderedDict([
    ("2hmace",   (["mace2h", "mace2hmetal"], None)),
    ("1hmace",   (["mace1h", "mace1hmetal"], None)),
    ("2hsword",  (["sword2h"], None)),
    ("1hsword",  (["sword1h"], None)),
    ("2haxe",    (["axe2h"], None)),
    ("1haxe",    (["axe1h"], None)),
    ("staff",    (["staff"], None)),
    ("dagger",   (["dagger"], None)),
    ("unarmed",  (["unarmed"], None)),
    ("bow",      (["bow"], r"impact|arrowhit")),
    ("gun",      (["gun"], r"impact")),
])
# weapon types that share another type's impact sounds
SHARED = {"fist": "unarmed", "crossbow": "bow"}

by_group = OrderedDict((k, []) for k in GROUPS)
for line in open(listfile, encoding="utf-8", errors="replace"):
    line = line.strip()
    if ";" not in line:
        continue
    fid, path = line.split(";", 1)
    p = path.lower()
    if not p.endswith(".ogg") or "npc" in p:
        continue
    parts = p.split("/")
    if len(parts) < 5:
        continue
    folder, name = parts[3], parts[-1]
    for key, (folders, pat) in GROUPS.items():
        if folder in folders and (pat is None or re.search(pat, name)):
            by_group[key].append(int(fid))

lines = [
    "-- Stock player-side weapon hit sounds, muted while a matching weapon type is",
    "-- equipped and switched on. File IDs from the wowdev community listfile",
    "-- (sound/item/weapons/*). NPC variants, swing whooshes, bow draws and gun",
    "-- shots are left out on purpose. Generated; see README for how.",
    "local _, ns = ...",
    "ns.MUTE = {",
]
total = 0
for key, ids in by_group.items():
    ids = sorted(set(ids))
    total += len(ids)
    lines.append('    ["%s"] = { -- %d files' % (key, len(ids)))
    for i in range(0, len(ids), 10):
        lines.append("        " + ", ".join(str(x) for x in ids[i:i + 10]) + ",")
    lines.append("    },")
lines.append("}")
for alias, target in SHARED.items():
    lines.append('ns.MUTE["%s"] = ns.MUTE["%s"]' % (alias, target))
open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
for key, ids in by_group.items():
    print(key, len(set(ids)))
print("total", total)
