#!/usr/bin/env python3
"""v0.24 "the Ember-bearer": the hero has no name of his own any more (four callings); the Shahnameh's people take the parts
that are theirs. This does the mechanical renames (idempotent) and puts the new villagers on the village map:
  Elder Godarz -> Zal (the white-haired lord of Zabol, Rostam's father)
  Kaveh the Smith -> Kavian the Smith (of Kaveh's house: the legend of Kaveh belongs to chapter 3)
  + Rostam (the training yard), Siavash (by the Trial's gate), Gordafarid (by the Bounty Board)
Chapter 3's own lines (Kaveh, Qaren) and the heroes' callings are written by hand in the code.

    python3 tools/ember_bearer.py
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = [
    (r"\bElder Godarz\b", "Zal"),
    (r"\bspeak with the Elder\b", "speak with Zal"),
    (r"\breturn to the Elder\b", "return to Zal"),
    (r"\bKaveh the Smith\b", "Kavian the Smith"),
    (r"\bKaveh's armor\b", "Kavian's armor"),
    (r"\bKaveh forges armor\b", "Kavian forges armor"),
    (r"\bKaveh can refine\b", "Kavian can refine"),
    (r"\bKaveh and Sindokht\b", "Kavian and Sindokht"),
    (r"\bKaveh sells some\b", "Kavian sells some"),
    (r"\bKaveh refines\b", "Kavian refines"),
    (r"\bKaveh's armour\b", "Kavian's armour"),
    (r"\bKaveh's choice\b", "Kavian's choice"),
    (r"\bKaveh armour\b", "Kavian armour"),
]
FA = [
    ("ریش‌سفید گودرز", "زال"),
    ("نزد ریش‌سفید برگرد", "نزد زال برگرد"),
    ("با ریش‌سفید صحبت کن", "با زال صحبت کن"),
    ("کاوهٔ آهنگر", "کاویانِ آهنگر"),
    ("زرهِ کاوه", "زرهِ کاویان"),
    ("و کاوه زره می‌سازد", "و کاویان زره می‌سازد"),
    ("کاوه می‌تواند", "کاویان می‌تواند"),
    ("کاوه و سیندخت", "کاویان و سیندخت"),
    ("کاوه زره می‌فروشد", "کاویان زره می‌فروشد"),
]
SKIP = {"chapter3.gd", "chapter3test.gd", "ch3shots.gd", "ember_bearer.py", "shahnameh_names.py", "CHANGELOG.md"}

def files():
    for base in ["scripts", "data", "tests"]:
        for dp, _, fs in os.walk(os.path.join(ROOT, base)):
            for f in fs:
                if f.endswith((".gd", ".json")) and f not in SKIP:
                    yield os.path.join(dp, f)

changed = 0
for p in files():
    s = open(p, encoding="utf-8").read()
    o = s
    for a, b in EN:
        s = re.sub(a, b, s)
    for a, b in FA:
        s = s.replace(a, b)
    if s != o:
        open(p, "w", encoding="utf-8").write(s)
        n = sum(1 for x, y in zip(o.splitlines(), s.splitlines()) if x != y)
        changed += n
        print("%s: %d lines" % (os.path.relpath(p, ROOT), n))
print("changed lines:", changed)

# the strings table: the new names
p = os.path.join(ROOT, "data", "strings_en_fa.json")
d = json.load(open(p, encoding="utf-8"))
have = {e["en"] for e in d}
NAMES = {"Zal": "زال", "Kavian the Smith": "کاویانِ آهنگر", "Rostam": "رستم", "Siavash": "سیاوش", "Gordafarid": "گردآفرید"}
for en, fa in NAMES.items():
    if en not in have:
        d.append({"en": en, "fa": fa})
for e in d:
    if e["en"] in NAMES:
        e["fa"] = NAMES[e["en"]]
open(p, "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False, indent=1))

# the village: Rostam's training yard by the hay, Siavash by the Trial's gate, Gordafarid by the Bounty Board
p = os.path.join(ROOT, "data", "Maps", "village.json")
md = json.load(open(p, encoding="utf-8"))
npcs = [n for n in md["data"]["npcs"] if n["id"] not in ("rostam", "siavash", "gordafarid")]
npcs += [
    {"id": "rostam", "x": 552, "y": 144, "w": 26, "h": 34, "color": "#b07030", "name": "Rostam", "_en": "Rostam"},
    {"id": "siavash", "x": 700, "y": 380, "w": 26, "h": 34, "color": "#e0d0a0", "name": "Siavash", "_en": "Siavash"},
    {"id": "gordafarid", "x": 290, "y": 330, "w": 26, "h": 34, "color": "#506080", "name": "Gordafarid", "_en": "Gordafarid"},
]
md["data"]["npcs"] = npcs
json.dump(md, open(p, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print("village npcs:", [n["id"] for n in npcs])
