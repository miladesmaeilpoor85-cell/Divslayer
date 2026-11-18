#!/usr/bin/env python3
"""Persian text pass (v0.23), from the mobile-games critic's review: one word for one thing, no loan-translations, no
Christian or Tolkien words in a Shahnameh world. Literal Persian replacements only (English is untouched); idempotent.

    python3 tools/fa_glossary.py          # applies and prints every changed line
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# (old, new) — longer phrases first
PAIRS = [
    # the parry: "پرِی" reads as "fairy"
    ("۲۰ ضربه را با پرِی کامل دفع کن", "۲۰ بار دفاعِ بی‌نقص کن"),
    ("پرِی کامل", "دفاعِ بی‌نقص"),
    ("پرِی!", "دفاعِ بی‌نقص!"),
    # gear: no fridges, no cleavers, no mithril
    ("سپر یخچالی", "جوشنِ یخین"),
    ("یخچال‌شکن", "یخ‌کوه‌شکن"),
    ("ساطور نیش‌اخگر", "تیغِ اخگرنیش"),
    ("تیغ میتریل", "تیغِ هندی"),
    ("قلب ققنوس", "پرِ سیمرغ"),
    # words from another world
    ("قدیسِ خاکستر", "پارسای خاکستر"),
    ("اخگرحامل", "اخگردار"),
    ("خدایان زابل را نگه دارند", "یزدان زابل را نگه دارد"),
    ("تورْوین", "بهزاد"),
    ("کوبه‌ی مقدس", "کوبهٔ فرّه"),
    ("سوگند یک پالادین", "سوگندِ یک پهلوانِ پاک‌دل"),
    ("[پالادین]", "[سوگندوَر]"),
    ('"paladin": "پالادین"', '"paladin": "سوگندوَر"'),
    ('["Paladin", "پالادین"]', '["Paladin", "سوگندوَر"]'),
    ("[جادوگر]", "[فرزانه]"),
    ('"mage": "جادوگر"', '"mage": "فرزانه"'),
    ('["Mage", "جادوگر"]', '["Mage", "فرزانه"]'),
    # titles
    ("خفته‌ی زیرین", "خفته در ژرفا"),
    ("قلدرِ باتلاق", "دیوِ مرداب"),
    ("خداوندگار آهنگرخانه‌ی اخگر", "سالارِ آهنگرخانهٔ اخگر"),
    # places: one name each
    ("سردابه‌ی غرق‌شده", "سردابِ فرورفته"),
    ("سردابِ غرق‌شده", "سردابِ فرورفته"),
    ("سرداب غرق‌شده", "سردابِ فرورفته"),
    ("مرداب سایه‌فن", "مردابِ سایه"),
    ("بوگ‌بلوم", "گلِ مرداب"),
    # phrasing
    ("دو دکمه، هر دو جادویی که بخواهی: برای بستن ۱ یا ۲ را بزن.", "دو دکمه برای دو جادویی که بخواهی: هر جادو را با زدنِ ۱ یا ۲ روی یکی از دو دکمه بگذار."),
    ("هی — قبل از خرید یک لحظه.", "پیش از آن‌که چیزی بخری، یک سخن."),
    ("نبردها را دوباره زندگی کن", "نبردها را دوباره از سر بگذران"),
]
EN_PAIRS = [("Phoenix Heart", "Simurgh's Feather")]

def files():
    for base in ["scripts", "data", "tests"]:
        for dp, _, fs in os.walk(os.path.join(ROOT, base)):
            for f in fs:
                if f.endswith((".gd", ".json")):
                    yield os.path.join(dp, f)

changed = 0
for p in files():
    s = open(p, encoding="utf-8").read()
    o = s
    for a, b in PAIRS + ([] if "/tests/" in p else EN_PAIRS):
        s = s.replace(a, b)
    if s != o:
        open(p, "w", encoding="utf-8").write(s)
        n = sum(1 for x, y in zip(o.splitlines(), s.splitlines()) if x != y)
        changed += n
        print("%s: %d lines" % (os.path.relpath(p, ROOT), n))
print("changed lines:", changed)
