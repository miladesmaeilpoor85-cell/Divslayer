#!/usr/bin/env python3
"""v0.22: the names of the Shahnameh. Fernbrook becomes Zabol; the villagers, the four heroes and the bosses take names from
Ferdowsi's Shahnameh. This script rewrites every text (English and Persian) in the scripts, the data tables, the maps and the
strings table; the ids in code and in saves (elder, smith, brann, keeper, hesk, boss, boss2, ...) stay as they were.
It is idempotent (run it again: nothing more changes) and prints every line it changed, for review.

    python3 tools/shahnameh_names.py [--dry]

Who is who (old -> new):
  village   Fernbrook -> Zabol (زابل)
  elder     Elder Rowan -> Elder Godarz (ریش‌سفید گودرز)       smith     Blacksmith Garen -> Kaveh the Smith (کاوهٔ آهنگر)
  merchant  Merchant Thalia -> Sindokht (سیندخت)              alchemist Alchemist Miri -> Rudabeh (رودابه)
  brann     Brann the Exile -> Jamshid the Exile (جمشیدِ تبعیدی) keeper   the Memory Keeper -> Sorush (سروش)
  hesk      Hesk the Trapper -> Hom the Trapper (هومِ تله‌گذار)
  boss      the Dungeon Guardian -> Arzhang the Div (ارژنگ دیو)  boss2    the Ember Colossus -> the King of Mazandaran (شاه مازندران)
  matriarch the Marsh Matriarch -> the Sorceress (زنِ جادو)     arbiter  the Frostbound Arbiter -> the White Div (دیو سپید)
  ignarok   Ignarok -> Puladvand (پولادوند)                   glaciertitan the Glacier Titan -> Akvan the Div (اکوان دیو)
  ancientwyrm the Ancient Wyrm -> the Dragon of Kashaf (اژدهای کشف‌رود)
  toadking  the Toad King -> Bid the Div (دیو بید)            anvilward the Warden of the Anvil -> Pulad of Ghandi (پولادِ غندی)
  captain   Varga the Red -> Ashkbus of Kushan (اشکبوسِ کشانی)
  heroes    warrior Rostam (رستم), mage Zal (زال), rogue Gordafarid (گردآفرید), paladin Siavash (سیاوش) — in game.gd HERO_NAMES
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# English: regex, replacement — the longest first; names are capitalised, code ids are not, so ids are safe
EN = [
	(r"\bFernbrook Village\b", "Zabol"), (r"\bFernbrook\b", "Zabol"),
	(r"\bElder Rowan\b", "Elder Godarz"), (r"\bRowan\b", "Godarz"),
	(r"\bBlacksmith Garen\b", "Kaveh the Smith"), (r"\bGaren\b", "Kaveh"),
	(r"\bMerchant Thalia\b", "Sindokht the Merchant"), (r"\bThalia the merchant\b", "Sindokht the merchant"), (r"\bThalia\b", "Sindokht"),
	(r"\bAlchemist Miri\b", "Rudabeh the Alchemist"), (r"\bMiri\b", "Rudabeh"),
	(r"\bBrann\b", "Jamshid"),
	(r"\bThe Memory Keeper\b", "Sorush"), (r"\bthe Memory Keeper\b", "Sorush"), (r"\bMemory Keeper\b", "Sorush"),
	(r"\bthe Keeper's\b", "Sorush's"), (r"\bthe Keeper\b", "Sorush"), (r"\bThe Keeper\b", "Sorush"),
	(r"\bHesk\b", "Hom"),
	(r"\bVarga the Red\b", "Ashkbus of Kushan"), (r"\bVarga\b", "Ashkbus"),
	(r"\bIgnarok\b", "Puladvand"),
	(r"\bGuardian's Bulwark\b", "Arzhang's Bulwark"), (r"\bGuardian-slayer\b", "Arzhang-slayer"),
	(r"\b[Tt]he Guardian of the Crypt\b", "Arzhang the Div"),
	(r"\bThe Dungeon Guardian\b", "Arzhang the Div"), (r"\bthe Dungeon Guardian\b", "Arzhang the Div"), (r"\bA Dungeon Guardian\b", "Arzhang the Div"),
	(r"\bDungeon Guardian\b", "Arzhang the Div"), (r"\bthe Guardian's\b", "Arzhang's"), (r"\b[Tt]he Guardian\b", "Arzhang"),
	(r"\bColossus Emberheart\b", "Emberheart of Mazandaran"),
	(r"\bThe Ember Colossus\b", "The King of Mazandaran"), (r"\bthe Ember Colossus\b", "the King of Mazandaran"), (r"\bEmber Colossus\b", "King of Mazandaran"),
	(r"\bthe Colossus'", "the King's"), (r"\bthe Colossus\b", "the King of Mazandaran"), (r"\bThe Colossus\b", "The King of Mazandaran"),
	(r"\bMatriarch's Fang\b", "Sorceress's Fang"),
	(r"\bThe Marsh Matriarch\b", "The Sorceress"), (r"\bA Marsh Matriarch\b", "The Sorceress"), (r"\bthe Marsh Matriarch\b", "the Sorceress"),
	(r"\bMarsh Matriarch\b", "Sorceress"), (r"\bthe Matriarch\b", "the Sorceress"), (r"\bThe Matriarch\b", "The Sorceress"), (r"\bMatriarch\b", "Sorceress"),
	(r"\bArbiter's Rime\b", "White Div's Rime"),
	(r"\bThe Frostbound Arbiter\b", "The White Div"), (r"\bthe Frostbound Arbiter\b", "the White Div"), (r"\bFrostbound Arbiter\b", "White Div"),
	(r"\bthe Arbiter\b", "the White Div"), (r"\bArbiter\b", "White Div"),
	(r"\bThe Glacier Titan\b", "Akvan the Div"), (r"\bthe Glacier Titan's\b", "Akvan's"), (r"\bthe Glacier Titan\b", "Akvan the Div"),
	(r"\bGlacier Titan's\b", "Akvan's"), (r"\bGlacier Titan\b", "Akvan the Div"), (r"\ba Titan's heart\b", "a div's heart"),
	(r"\bthe Titan's\b", "Akvan's"), (r"\b[Tt]he Titan\b", "Akvan"), (r"\bTitan\b", "Akvan"),
	(r"\bThe Ancient Wyrm\b", "The Dragon of Kashaf"), (r"\bthe Ancient Wyrm\b", "the Dragon of Kashaf"), (r"\bAncient Wyrm\b", "Dragon of Kashaf"),
	(r"\bher Toad King\b", "Bid the Div"), (r"\bThe Toad King\b", "Bid the Div"), (r"\bthe Toad King\b", "Bid the Div"), (r"\bToad King\b", "Bid the Div"),
	(r"\b[Tt]he Warden of the Anvil\b", "Pulad of Ghandi"), (r"\bWarden of the Anvil\b", "Pulad of Ghandi"),
]

# Persian: literal text, replacement — the longest first (the HTML game's own translations used other names too)
FA = [
	("روستای فرن‌بروک", "زابل"), ("دهکده فرن‌بروک", "دهکدهٔ زابل"), ("فرن‌بروک", "زابل"),
	("بزرگسالِ ردوان", "ریش‌سفید گودرز"), ("ریش‌سفید رُوان", "ریش‌سفید گودرز"), ("رُوان", "گودرز"),
	("آهنگر گارِن", "کاوهٔ آهنگر"), ("گارِن", "کاوه"), ("گارن", "کاوه"),
	("بازرگان تالیا", "سیندختِ بازرگان"), ("تالیا", "سیندخت"),
	("کیمیاگر میری", "کیمیاگر رودابه"),
	("برَن تبعیدی", "جمشیدِ تبعیدی"), ("برَنِ تبعیدی", "جمشیدِ تبعیدی"), ("برَن", "جمشید"),
	("نگهبانِ یادها", "سروش"), ("خزانهٔ یخ‌زدهٔ نگهبان", "خزانهٔ یخ‌زدهٔ سروش"), ("نزد نگهبان برگرد", "نزد سروش برگرد"), ("سپاسِ نگهبان", "سپاسِ سروش"),
	("هِسکِ تله‌گذار", "هومِ تله‌گذار"), ("هسک", "هوم"),
	("وارگای سرخ", "اشکبوسِ کشانی"), ("وارگا", "اشکبوس"),
	("ایگنارُک", "پولادوند"),
	("نگهبانِ سیاه‌خانه", "ارژنگ دیو"), ("نگهبان سیاه‌خانه", "ارژنگ دیو"), ("نگهبانِ سرداب", "ارژنگ دیو"), ("نگهبان سرداب", "ارژنگ دیو"),
	("نگهبان را شکست دادی", "ارژنگ را شکست دادی"), ("سقوط نگهبان", "سقوطِ ارژنگ"), ("نگهبان را هنوز نکشته", "ارژنگ را هنوز نکشته"),
	("[کُشنده‌ی نگهبان]", "[کُشندهٔ ارژنگ]"), ("سپر نگهبان", "سپرِ ارژنگ"), ("ستون‌ها از نگهبان محافظت", "ستون‌ها از ارژنگ محافظت"),
	("غولِ اخگر", "شاه مازندران"), ("غول اخگر", "شاه مازندران"), ("غولِ سوزان", "شاه مازندران"), ("قلب‌اخگر غول", "قلب‌اخگرِ مازندران"),
	("غول را زمین زدی", "شاه مازندران را زمین زدی"),
	("ملکه‌ی مرداب", "زنِ جادو"), ("ملکهٔ مرداب", "زنِ جادو"), ("بانوی مرداب", "زنِ جادو"), ("ملکه‌ی باتلاق", "زنِ جادو"),
	("نیش مادرسالار", "نیشِ زنِ جادو"), ("شاه‌قورباغه‌اش", "دیو بید"),
	("داورِ یخ‌بسته", "دیو سپید"), ("داور یخ‌بسته", "دیو سپید"), ("داورِ یخ‌زده", "دیو سپید"), ("برفک داور", "برفکِ دیو سپید"),
	("تو داور را", "تو دیو سپید را"), ("داور هنوز تکه‌اش", "دیو سپید هنوز تکه‌اش"),
	("غول یخچال", "اکوان دیو"), ("قلبِ یخیِ غول", "قلبِ یخیِ اکوان"), ("غول در دلِ درهٔ یخ‌بندان", "اکوان در دلِ درهٔ یخ‌بندان"),
	("قلبِ یک غول است", "قلبِ یک دیو است"), ("روزِ بیستم. غول از", "روزِ بیستم. اکوان از"), ("یا روی غول بمان", "یا روی اکوان بمان"),
	("اژدهای کهن", "اژدهای کشف‌رود"), ("اژدهای باستانی", "اژدهای کشف‌رود"),
	("شاه وزغ", "دیو بید"), ("شاه‌وزغ", "دیو بید"),
	("نگهبان سندان", "پولادِ غندی"),
]

def files():
	for base in ("scripts", "data", "tests"):
		for dp, _, fs in os.walk(os.path.join(ROOT, base)):
			for f in fs:
				if f.endswith(".gd") or f.endswith(".json"):
					if f in ("icons.json", "art_manifest.json", "map_object_sprites.json", "world_graph.json", "hero_masks.json"):
						continue
					yield os.path.join(dp, f)

def rename(s: str) -> str:
	for a, b in EN:
		s = re.sub(a, b, s)
	for a, b in FA:
		s = s.replace(a, b)
	return s

def main():
	dry = "--dry" in sys.argv
	total = 0
	for p in sorted(files()):
		s = open(p, encoding="utf-8").read()
		t = rename(s)
		if t == s:
			continue
		old = s.splitlines()
		new = t.splitlines()
		n = 0
		for a, b in zip(old, new):
			if a != b:
				n += 1
				print("%s\n  - %s\n  + %s" % (os.path.relpath(p, ROOT), a.strip()[:200], b.strip()[:200]))
		total += n
		if not dry:
			open(p, "w", encoding="utf-8").write(t)
	print("%d lines %s" % (total, "would change" if dry else "changed"))

if __name__ == "__main__":
	main()
