#!/usr/bin/env python3
"""v0.24 text pass (the playtest's critic, Negar, and the gamer, Arash): the leftovers of the hero's old identity, the
Shahnameh slips in Zabol's lines, and one style for the Persian text. Safe to run again: a pair whose old text is gone
and whose new text is there counts as done.

    python3 tools/v24_text.py            (prints what changed; exits 1 if a pair finds neither its old nor its new text)

After the pairs, two sweeps over every Persian string (scripts/**/*.gd, data/*.json, data/Tables/*.json):
  - the ezafe after a silent he is written هٔ (it was ه‌ی in 110 strings and هٔ in 79); زره, whose he is spoken, takes a
    kasra: زرهِ.
  - the middle dot "·" between items reads as the Persian zero "۰" in this font: in Persian strings it becomes "،".
  - "باس" (boss) is سرکرده, the word Sorush uses.
"""
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

# (file or "*", old, new) — "*" = every file of the sweep
PAIRS = [
    # ---- the hero has no name; Zal is the elder; Champion -> Ember-bearer
    ("scripts/toll.gd", '"o_fame": ["Your name alone was enough.", "نامت به‌تنهایی کافی بود."]',
     '"o_fame": ["Your renown alone was enough.", "آوازه‌ات به‌تنهایی کافی بود."]'),
    ("data/strings_en_fa.json", '"نامت به‌تنهایی کافی بود."', '"آوازه‌ات به‌تنهایی کافی بود."'),
    ("scripts/chapter2.gd", '"e1": ["Champion... you feel it too?', '"e1": ["Ember-bearer... you feel it too?'),
    ("scripts/chapter2.gd", '"قهرمان... تو هم حسش می‌کنی؟', '"اخگردار... تو هم حسش می‌کنی؟'),
    ("scripts/chapter2.gd", '"e_hurry": ["The tremors grow worse, champion. Do not tarry.", "لرزه‌ها بدتر می‌شوند، قهرمان. درنگ نکن."]',
     '"e_hurry": ["The tremors grow worse, ember-bearer. Do not tarry.", "لرزه‌ها بدتر می‌شوند، اخگردار. درنگ نکن."]'),
    ("scripts/chapter2.gd", "Rest now, champion — the Vale, the Forge and the shrines", "Rest now, ember-bearer — the Vale, the Forge and the shrines"),
    ("scripts/chapter2.gd", "حالا بیاسا، قهرمان — دره، کوره و معبدها", "حالا بیاسا، اخگردار — دره، کوره و زیارتگاه‌ها"),
    ("data/strings_en_fa.json", '"نبرد پیاپی آغاز شده. ادامه بده، قهرمان!"', '"نبرد پیاپی آغاز شده. ادامه بده، اخگردار!"'),
    ("data/strings_en_fa.json", '"ارژنگ را شکست دادی! این سکه‌ها را بگیر، قهرمان."', '"ارژنگ را شکست دادی! این سکه‌ها را بگیر، اخگردار."'),
    ("data/strings_en_fa.json", '"تو قهرمانِ زابلی. این پاداش آخر را بگیر!"', '"زابل وامدارِ توست، اخگردار. این پاداش را بگیر!"'),
    ("data/strings_en_fa.json", '"خنیاگران نسل‌ها از تو خواهند خواند، قهرمان."', '"خنیاگران نسل‌ها از تو خواهند خواند، اخگردار."'),
    ("scripts/trial.gd", 'Game.t("A champion comes!", "یک قهرمان می‌آید!")', 'Game.t("A champion of the foe comes!", "گُردی از سپاهِ دشمن می‌آید!")'),
    ("scripts/menu.gd", '"تو اخگرداری — کالبدت را برگزین"', '"تو اخگرداری — راهت را برگزین"'),
    ("scripts/pause_menu.gd", "unleash your class's ultimate.", "unleash your calling's ultimate."),
    ("scripts/pause_menu.gd", "ضربهٔ نهایی کلاست را رها کن.", "ضربهٔ نهاییِ راهت را رها کن."),
    ("data/strings_en_fa.json", '"Your name alone was enough."', '"Your renown alone was enough."'),
    ("data/strings_en_fa.json", '"HOLY SMITE!"', '"FARR SMITE!"'),
    ("data/strings_en_fa.json", '"You are the Champion of Zabol. Take this final reward!"', '"Zabol owes you much, ember-bearer. Take this reward!"'),
    # ---- ember, not ash
    ("*", "آزمونِ خاکستر", "آزمونِ اخگر"),
    ("*", "آزمون اخگرها", "آزمونِ اخگر"),
    ("data/strings_en_fa.json", "حماسه‌ی خاکستر را دنبال کن", "حماسهٔ اخگر را دنبال کن"),
    # ---- one name for each thing
    ("*", "ضربه‌ی بحرانی", "ضربهٔ کاری"),
    ("*", "ضربهٔ بحرانی", "ضربهٔ کاری"),
    ("data/strings_en_fa.json", '"ضربات بحرانی"', '"ضربه‌های کاری"'),
    ("*", "کماندار سردابه", "کماندارِ سرداب"),
    ("data/strings_en_fa.json", '"سردابه در شمال است، آن سوی جنگل نجوا."', '"سرداب در شمال است، آن سوی جنگلِ نجواگر."'),
    ("data/strings_en_fa.json", '"سیاه‌خانه‌ی فرو‌رفته"', '"سردابِ فرورفته"'),
    ("data/strings_en_fa.json", "بر فراز قله‌های خاکستری", "بر فرازِ قله‌های خاکستر"),
    ("data/Tables/V12_AREA.json", '"Crystal Sanctum": "معبد بلور"', '"Crystal Sanctum": "معبد بلورین"'),
    ("*", "جوهر", "عصاره"),
    ("data/strings_en_fa.json", "ملکه‌ی عنکبوت‌ها را در باتلاقِ سایه‌ها (غربِ قله‌ها) شکار کن.", "زنِ جادو را در مردابِ سایه (غربِ قله‌ها) شکار کن."),
    # shrine = زیارتگاه (the Crystal Sanctum stays a معبد)
    ("*", "معبدهای کهن", "زیارتگاه‌های کهن"),
    ("*", "معبدهای پاک‌شده", "زیارتگاه‌های پاک‌شده"),
    ("*", "هر هفت معبد کهن را کامل کن", "هر هفت زیارتگاهِ کهن را کامل کن"),
    ("scripts/main.gd", 'Game.t("SHRINE CLEANSED", "معبد پاک شد")', 'Game.t("SHRINE CLEANSED", "زیارتگاه پاک شد")'),
    ("scripts/main.gd", '"%s از %s معبد"', '"%s از %s زیارتگاه"'),
    ("scripts/chapter2.gd", "نشان‌های معبدها", "نشان‌های زیارتگاه‌ها"),
    ("scripts/chapter2.gd", "دره، کوره، معبدها، میدانِ آزمون", "دره، کوره، زیارتگاه‌ها، میدانِ آزمون"),
    ("*", "یک معبد کهن پنهان است", "یک زیارتگاهِ کهن پنهان است"),
    ("data/strings_en_fa.json", '"نشان معبد"', '"نشانِ زیارتگاه"'),
    ("*", '"معبد اخگر"', '"زیارتگاهِ اخگر"'), ("*", '"معبد سنگینی"', '"زیارتگاهِ سنگینی"'), ("*", '"معبد فتیله"', '"زیارتگاهِ فتیله"'),
    ("*", '"معبد جزر و مد"', '"زیارتگاهِ جزر و مد"'), ("*", '"معبد نور"', '"زیارتگاهِ نور"'), ("*", '"معبد پژواک"', '"زیارتگاهِ پژواک"'),
    ("*", '"معبد سایه‌ها"', '"زیارتگاهِ سایه‌ها"'),
    # boss = سرکرده (the Persian word the game's Sorush uses)
    ("scripts/ui/ending.gd", '"باس‌های کشته‌شده: %s"', '"سرکرده‌های از پا درآمده: %s"'),
    ("scripts/ui/credits.gd", '"نبرد با باس‌ها"', '"نبرد با سرکرده‌ها"'),
    # ---- register and words
    ("scripts/chapter3.gd", "درفشِ کاویانی بر فرازِ زابل در اهتزاز است.", "درفشِ کاویانی بر فرازِ زابل برافراشته است."),
    ("scripts/shop.gd", '"merchant": "آذوقه‌ی تازه برای راه!"', '"merchant": "تیغ و توشه برای راه!"'),
    ("scripts/shop.gd", '"smith": "پولادی که دوام بیاورد — وگرنه پولت را پس می‌دهم!"', '"smith": "آهنی که در کورهٔ کاوه تافته شود، نمی‌شکند."'),
    ("scripts/main.gd", 'Game.t("Steel that will hold — or your gold back!", "فولادی که تاب بیاورد — یا پولت را پس بگیر!")',
     'Game.t("Iron tempered in Kaveh\'s forge does not break.", "آهنی که در کورهٔ کاوه تافته شود، نمی‌شکند.")'),
    ("scripts/shop.gd", '"  (نسبت به الان)"', '"  (نسبت به اکنون)"'),
    ("scripts/boss.gd", 'Game.t("Phase II", "فاز دوم") if ph == 2 else Game.t("Final phase", "فاز آخر")',
     'Game.t("Phase II", "مرحلهٔ دوم") if ph == 2 else Game.t("Final phase", "واپسین مرحله")'),
    ("data/strings_en_fa.json", '"فاز دوم"', '"مرحلهٔ دوم"'), ("data/strings_en_fa.json", '"فاز آخر"', '"واپسین مرحله"'),
    ("scripts/gear.gd", '"گام‌زنان فاز"', '"گام‌زنانِ گذرا"'),
    ("data/Tables/MON_SKINS.json", '"زاده‌ی یخبندان"', '"زادهٔ یخ‌بندان"'),
    ("data/Tables/MON_SKINS.json", '"پیمان ابسیدین"', '"پیمانِ سنگِ سیاه"'),
    ("*", "شوالیه‌ی یخ‌بسته", "سوارِ یخ‌بسته"),
    ("data/Tables/FF_SKILLS.json", '"nameEn": "Arcane Bolt",\n  "nameFa": "تیر جادویی"', '"nameEn": "Ember Bolt",\n  "nameFa": "تیرِ اخگر"'),
    ("scripts/achievements.gd", '"Silver Tongue", "زبانِ نقره‌ای"', '"Sweet-Spoken", "شیرین‌سخن"'),
    # Jahan-Pahlavan is Rostam's own title: the look becomes the robe he gives
    ("data/Tables/MON_SKINS.json", '"nameFa": "جهان‌پهلوان"', '"nameFa": "خلعتِ رستم"'),
    ("data/Tables/MON_SKINS.json", '"nameEn": "Jahan-Pahlavan"', '"nameEn": "Rostam\'s Robe of Honour"'),
    # Holy Smite -> the Farr's
    ("scripts/skills.gd", '"name": ["Holy Smite", "کوبهٔ فرّه"], "shout": ["HOLY SMITE!", "کوبهٔ فرّه!"]',
     '"name": ["Farr Smite", "کوبهٔ فرّه"], "shout": ["FARR SMITE!", "کوبهٔ فرّه!"]'),
    ("data/Tables/CLASSES.json", '"ultName": "Holy Smite"', '"ultName": "Farr Smite"'),
    ("scripts/caster.gd", "Shadow Dance, Holy Smite.", "Shadow Dance, Farr Smite."),
    # Hom's lost companion: one name in both languages (Behzad is Siavash's horse)
    ("scripts/chapter2.gd", "Torvin swears the mountain hums at night", "Mehran swears the mountain hums at night"),
    ("scripts/chapter2.gd", "بهزاد قسم می‌خورد", "مهران سوگند می‌خورد"),
    # ---- the Shahnameh (critic's notes)
    ("scripts/toll.gd", "Siavash would have smiled. Perhaps there's hope", "Siavash will smile when he hears of it. Perhaps there's hope"),
    ("scripts/toll.gd", "سیاوش لبخند می‌زد. شاید", "سیاوش بشنود، لبخند می‌زند. شاید"),
    ("scripts/chapter3.gd", '"z_phase": ["A thousand years in chains — and still I am king!", "هزار سال در زنجیر — و هنوز شاهم!"]',
     '"z_phase": ["A thousand years I reigned — and still I am king!", "هزار سال شاهی کردم — و هنوز شاهم!"]'),
    ("*", "Judge of the Crystal Sanctum", "Usurper of the Crystal Sanctum"),
    ("*", "قاضیِ معبد بلورین", "غاصبِ معبدِ بلورین"),
    ("scripts/chapter2.gd",
     '"k3": ["One shard they gave to the Judge of this Sanctum, the White Div. Another they sealed in Akvan\'s heart, in the Hoarfrost Vale to the east.", "یک تکه را به داورِ این معبد سپردند، دیو سپید. تکهٔ دیگر را در قلبِ اکوان دیو مهر کردند، در درهٔ یخ‌بندان، شرقِ این‌جا."]',
     '"k3": ["The White Div took this hall from me, and holds one shard in his fist. Another the Smiths sealed in Akvan\'s heart, in the Hoarfrost Vale to the east.", "دیو سپید این تالار را از من گرفت و یک تکه را در مشتش نگه داشته است. تکهٔ دیگر را آهنگران در قلبِ اکوان دیو مهر کردند، در درهٔ یخ‌بندان، شرقِ این‌جا."]'),
    # ---- Sindokht: three pages, not five; her own register
    ("scripts/main.gd", '[T.line("t_intro1"), T.line("t_intro2"), T.line("t_intro3"), T.line("t_after1"), T.line("t_after2")]',
     '[T.line("t_intro_a"), T.line("t_intro_b"), T.line("t_after")]'),
    ("scripts/toll.gd", '	"t_after1": [', '''	"t_intro_a": ["A word before you browse. Bandits under Ashkbus of Kushan have made camp in the Thornwood, south of the Whispering Forest — and they robbed my caravan from Kabul. My strongbox is in his camp.",
		"پیش از آن‌که چیزی بخری، یک سخن. راهزن‌های اشکبوسِ کشانی در خارزار اردو زده‌اند، جنوبِ جنگلِ نجواگر — و کاروانم را که از کابل می‌آمد زدند. صندوقچه‌ام در اردوگاهِ اوست."],
	"t_intro_b": ["I once turned Sam's wrath from Kabul's gates with gifts and gentle words. Fight them, talk to them, or slip in like a shadow — just bring it home.",
		"من روزی خشمِ سام را با هدیه و سخنِ نرم از دروازه‌های کابل برگرداندم. بجنگ، سخن بگو، یا چون سایه بی‌صدا درون شو — فقط برش گردان."],
	"t_after": ["The camp is a palisade of sharpened logs, with archers on watch. Rather not be seen? Move slowly, keep to the tall grass, out of their torchlight.",
		"دورِ اردوگاه حصاری از کنده‌های تیز است و کماندارها نگهبانی می‌دهند. اگر نمی‌خواهی دیده شوی: آهسته برو، در علفِ بلند بمان و از نورِ مشعل‌هایشان دور باش."],
	"t_after1": ['''),
    ("scripts/toll.gd", "نامه‌های خاندانم و سکه‌های زابل توی آن است.", "نامه‌های خاندانم و سکه‌های زابل در آن است."),
    ("scripts/toll.gd", "من روزی سپاهِ سام را تنها با سخن از دروازه‌های کابل برگرداندم. بجنگ، حرف بزن، یا مثل سایه بی‌صدا برو تو — فقط برش گردان.",
     "من روزی خشمِ سام را با هدیه و سخنِ نرم از دروازه‌های کابل برگرداندم. بجنگ، سخن بگو، یا چون سایه بی‌صدا درون شو — فقط برش گردان."),
    ("scripts/toll.gd", "I once turned Sam's army from Kabul's gates with words alone.", "I once turned Sam's wrath from Kabul's gates with gifts and gentle words."),
    ("data/strings_en_fa.json", "همه‌ی دارایی‌ام توی آن است.", "همهٔ دارایی‌ام در آن است."),
    ("data/strings_en_fa.json", "یا مثل سایه بی‌صدا برو تو — فقط برش گردان.", "یا چون سایه بی‌صدا درون شو — فقط برش گردان."),
    # ---- Siavash and Gordafarid (main.gd heads)
    ("scripts/main.gd", 'Game.t("Survive escalating waves. Leave anytime via the southern gate.", "در برابر موج‌های فزاینده بایست. هر وقت خواستی از دروازه‌ی جنوبی خارج شو.")',
     'Game.t("Waves come one after another; leave by the southern gate whenever you wish.", "موج‌ها پیاپی می‌آیند؛ هر گاه خواستی از دروازهٔ جنوبی بیرون شو.")'),
    ("scripts/main.gd", 'head = Game.t("The Trial is a fire, ember-bearer. I rode through one once, and came out whole. ", "آزمون آتش است، اخگردار. من روزی از میانِ آتش گذشتم و بی‌گزند بیرون آمدم. ") + head',
     'head = Game.t("Rostam raised me here in Zabol. I rode through fire once and came out whole — the Trial of Embers is a fire too, ember-bearer.", "رستم مرا در همین زابل پرورد. روزی از میانِ آتش گذشتم و بی‌گزند بیرون آمدم — آزمونِ اخگر هم آتش است، اخگردار.") + "\\n" + head'),
    ("scripts/main.gd", "# (v0.24) Gordafarid keeps the bounties: she held the White Fortress against Sohrab",
     "# (v0.24) Gordafarid keeps the bounties: she fought Sohrab at the White Fortress and slipped his grasp"),
    ("scripts/main.gd", 'head = Game.t("I held the White Fortress against Sohrab; I can hold a list of beasts. ", "من دژِ سپید را در برابرِ سهراب نگه داشتم؛ فهرستِ چند جانور را هم نگه می‌دارم. ") + head',
     'head = Game.t("I fought Sohrab at the White Fortress and slipped from his grasp; keeping a list of beasts is nothing.", "من پای دژِ سپید با سهراب جنگیدم و از چنگش رستم؛ نگه داشتنِ فهرستِ چند جانور کاری نیست.") + "\\n" + head'),
    ("scripts/main.gd", 'Game.t("Three contracts. Finish one, another appears.", "سه قرارداد. یکی را تمام کن، یکی دیگر می‌آید.") + "  " + Game.t',
     'Game.t("Three contracts. Finish one, another appears.", "سه قرارداد. یکی را تمام کن، یکی دیگر می‌آید.") + " " + Game.t'),
    # ---- Qaren's toast said the task's name twice; Kavian's count with no jewel yet
    ("scripts/main.gd", 'hud.toast(Game.Ch3.line("q_qaren") + " · " + Game.Ch3.fmt("t_guard", [int(Game.Ch3.qaren()["kills"]), Game.Ch3.GUARDS_NEED]), "scroll-text", UI.GOLD_HI)',
     'hud.toast(Game.Ch3.fmt("t_qtask", [int(Game.Ch3.qaren()["kills"]), Game.Ch3.GUARDS_NEED]), "scroll-text", UI.GOLD_HI)'),
    ("scripts/chapter3.gd", '	"t_guard": [', '''	"t_qtask": ["Qaren's task: the serpent guards (%d of %d)", "کارِ قارن: پاسدارانِ ماردوش (%d از %d)"],
	"t_guard": ['''),
    ("scripts/chapter3.gd", '"kj": ["%d of the three jewels. The banner waits for the rest.", "%d گوهر از سه. درفش منتظرِ بقیه است."]',
     '"kj": ["%d of the three jewels. The banner waits for the rest.", "%d گوهر از سه گوهر. درفش چشم‌به‌راهِ بقیه است."],\n	"kj0": ["No jewel yet. The banner waits.", "هنوز گوهری نیامده؛ درفش چشم‌به‌راه است."]'),
    ("scripts/chapter3.gd", '			return [fmt("kj", [jewels_have()])]', '			return [fmt("kj", [jewels_have()]) if jewels_have() > 0 else line("kj0")]'),
    # ---- Rostam's training: a post is a چوبه, not a ستون (pillar)
    ("scripts/tutorial.gd", '"t_strike": ["Strike the post three times — tap Attack.", "سه بار به ستونِ تمرین ضربه بزن — حمله را بزن."]',
     '"t_strike": ["Strike the post three times — tap Attack.", "سه بار به چوبهٔ تمرین بزن — دکمهٔ حمله را بزن."]'),
    ("scripts/tutorial.gd", '"حالا حمله را نگه دار تا حلقه پر شود، بعد رها کن: یک ضربهٔ سنگین روی ستون."', '"حالا دکمهٔ حمله را نگه دار تا حلقه پر شود، بعد رها کن: یک ضربهٔ سنگین بر چوبه."'),
    ("scripts/tutorial.gd", '"t_block": ["Last: hold Block and take my blow on your shield.", "آخرین: سپر را نگه دار و ضربه‌ام را روی سپرت بگیر."]',
     '"t_block": ["Last: hold Block and take my blow on your shield.", "و در پایان: دکمهٔ سپر را نگه دار و ضربه‌ام را روی سپرت بگیر."]'),
    ("scripts/tutorial.gd", '"تمرینِ رستم: به ستون ضربه بزن (%d/%d)"', '"تمرینِ رستم: به چوبه بزن (%d/%d)"'),
    ("scripts/tutorial.gd", '"تمرینِ رستم: یک ضربهٔ سنگین روی ستون (حمله را نگه دار)"', '"تمرینِ رستم: یک ضربهٔ سنگین بر چوبه (حمله را نگه دار)"'),
]

FILES = sorted(set(glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("data/*.json") + glob.glob("data/Tables/*.json")
                   + glob.glob("data/Maps/*.json")))
FA = re.compile(r"[؀-ۿ]")


def apply_pairs(texts: dict) -> int:
    bad = 0
    for f, old, new in PAIRS:
        targets = FILES if f == "*" else [f]
        hit = False
        for t in targets:
            s = texts[t]
            if old in new and new in s:
                hit = True         # an insertion already made
            elif old in s:
                texts[t] = s.replace(old, new)
                hit = True
                print(f"  {t}: {old[:60]!r} -> {new[:60]!r}")
            elif new in s:
                hit = True
        if not hit:
            print(f"MISSING {f}: {old[:80]!r}")
            bad += 1
    return bad


EZAFE = re.compile(r"ه‌ی(?![؀-ۿ])")
DOT = re.compile(r"[ \t]*·[ \t]*")
BOSS = re.compile(r"(?<![\u0600-\u06FF\u200c])باس(?:\u200cها|ِ)?(?![\u0600-\u06FF])")
STR = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def persian_sweep(s: str) -> str:
    def one(m):
        body = m.group(1)
        if not FA.search(body):
            return m.group(0)
        body = body.replace("زره‌ی", "زرهِ")
        body = EZAFE.sub("هٔ", body)
        body = BOSS.sub(lambda b: {"باس‌ها": "سرکرده‌ها", "باسِ": "سرکردهٔ"}.get(b.group(0), "سرکرده"), body)
        if "·" in body:
            lead = body.startswith((" ", "\t", "·")) and body.lstrip(" \t").startswith("·")
            body = DOT.sub("، ", body)
            if lead:
                body = body.lstrip()      # a suffix such as "  · magma armour" becomes "، زرهِ مذاب"
        return '"' + body + '"'
    return STR.sub(one, s)


def main() -> int:
    texts = {f: open(f, encoding="utf-8").read() for f in FILES}
    orig = dict(texts)
    bad = apply_pairs(texts)
    for f in FILES:
        texts[f] = persian_sweep(texts[f])
    changed = [f for f in FILES if texts[f] != orig[f]]
    for f in changed:
        open(f, "w", encoding="utf-8").write(texts[f])
    print(f"changed {len(changed)} files; {bad} pairs missing")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
