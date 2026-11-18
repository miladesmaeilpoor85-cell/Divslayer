#!/usr/bin/env python3
"""Localization lint: English strings shown through t()/Game.t() with no Persian, and not in data/strings_en_fa.json.
Also lists the lines Elder Godarz's tables return (plain string arrays turned by .map(t)).
    python3 tools/l10n_check.py
"""
import json, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
table = {e["en"]: e["fa"] for e in json.load(open(os.path.join(ROOT, "data", "strings_en_fa.json")))}
STR = r'"((?:[^"\\]|\\.)*)"'
one_arg = re.compile(r'(?<![A-Za-z_])t\(\s*' + STR + r'\s*\)')
missing = []
for dp, _, fs in os.walk(os.path.join(ROOT, "scripts")):
    for f in fs:
        if not f.endswith(".gd"):
            continue
        p = os.path.join(dp, f)
        src = open(p, encoding="utf-8").read()
        for m in one_arg.finditer(src):
            s = m.group(1).replace('\\"', '"').replace("\\n", "\n")
            if re.search(r"[A-Za-z]", s) and s not in table:
                missing.append((os.path.relpath(p, ROOT), src[:m.start()].count("\n") + 1, s))
# arrays of English lines that go through .map(t) (the Elder's quests)
g = open(os.path.join(ROOT, "scripts", "game.gd"), encoding="utf-8").read()
seg = g[g.index("func elder_lines"):g.index("func elder_has_news")]
seg_start = g.index(seg)
# comments and t("en", "fa") pairs carry their own Persian: blank them out (same length, so line numbers hold)
seg = re.sub(r"#[^\n]*", lambda m: " " * len(m.group(0)), seg)
paired = {m.start(1) for m in re.finditer(r'(?<![A-Za-z_])t\(\s*(' + STR + r')[^,\n]*,\s*"', seg)}
for m in re.finditer(STR, seg):
    if m.start() in paired:
        continue
    s = m.group(1).replace('\\"', '"')
    if re.search(r"[A-Za-z]{3}", s) and " " in s and s not in table:
        missing.append(("scripts/game.gd (elder_lines)", g[:seg_start + m.start()].count("\n") + 1, s))
# villagers' names on the maps (shown through Game.t)
for fn in sorted(os.listdir(os.path.join(ROOT, "data", "Maps"))):
    if fn.endswith(".json"):
        md = json.load(open(os.path.join(ROOT, "data", "Maps", fn), encoding="utf-8"))
        for n in md.get("data", {}).get("npcs", []) or []:
            nm = str(n.get("_en", n.get("name", "")))
            if nm and nm not in table:
                missing.append(("data/Maps/" + fn + " (npc name)", 0, nm))
for f, ln, s in missing:
    print("%s:%d  %s" % (f, ln, s[:110]))
print("MISSING %d" % len(missing))
sys.exit(1 if missing else 0)
