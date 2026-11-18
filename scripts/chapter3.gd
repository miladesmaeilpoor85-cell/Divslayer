extends RefCounted
## Chapter 3 — "The Chains of Damavand" (v0.23). Mine, from the Shahnameh: Zahhak, the serpent-shouldered king whom Fereydun
## bound beneath Mount Damavand (Sorush told him not to slay him: "his time is not yet"), and the Derafsh-e Kaviani, the
## leather apron Kaveh the smith raised on a spear against him.
##
## When the Dragon of Kashaf fell, the mountain answered: Zahhak's chains are cracking.
##   ""        chapter 2 not finished, or finished and Kavian (of Kaveh's house) has not yet spoken (his forge-fire burned black)
##   "jewels"  the road east of the Ashen Peaks is open: find the banner's three jewels on the Slopes of Damavand —
##             Kondrow's (his steward, on the ruined terrace), the fire temple's (light its three altars together) and
##             Qaren's (Kaveh's own son, old now, who stood beside Fereydun: thin out ten serpent guards)
##   "forge"   bring them to Kavian: he raises the Derafsh-e Kaviani again; the Gate of Damavand opens for it
##   "descend" go down into the Cave of Chains and overcome Zahhak (he is bound, not slain)
##   "bound"   return to Zal: the epilogue and the end of the chapter
##   "done"
## State: Game.state.c3 = {step, jewels: {kondrow, temple, qaren}, banner, altars_lit, altars_done (the temple chest),
##   qaren: {met, kills, st}}

const JEWELS := ["kondrow", "temple", "qaren"]
const GUARDS_NEED := 10
const GUARDS := ["serpentguard", "serpentarcher"]
const STEPS := ["", "jewels", "forge", "descend", "bound", "done"]
## the banner's strength where it was meant to be raised (Damavand and the cave)
const BANNER_MUL := 1.12

const L := {
	"title": ["The Chains of Damavand", "زنجیرهای دماوند"],
	"banner": ["Derafsh-e Kaviani", "درفشِ کاویانی"],
	"j_kondrow": ["Kondrow's jewel", "گوهرِ کُندرو"],
	"j_temple": ["the temple's jewel", "گوهرِ آتشکده"],
	"j_qaren": ["Qaren's jewel", "گوهرِ قارن"],
	"q_qaren": ["The Serpent Guards", "روزبانانِ ضحاک"],
	# ---- objective lines
	"o_kaveh": ["Speak with Kavian the Smith — his forge-fire burns black", "با کاویانِ آهنگر صحبت کن — آتشِ کوره‌اش سیاه شده"],
	"o_jewels": ["Find the banner's three jewels on Damavand (%d/3)", "سه گوهرِ درفش را در دماوند پیدا کن (%d/۳)"],
	"o_kondrow": [": Kondrow, on the north-west terrace", ": کُندرو، در ایوانِ شمال‌غرب"],
	"o_temple": [": the fire temple's three altars (south-east)", ": سه آتشدانِ آتشکده (جنوب‌شرق)"],
	"o_qaren_meet": [": speak with Qaren at the camp", ": با قارن در اردوگاه صحبت کن"],
	"o_qaren": [": Qaren's task — serpent guards %d/%d", ": کارِ قارن — روزبانانِ ضحاک %d/%d"],
	"o_qaren_back": [": return to Qaren", ": نزدِ قارن برگرد"],
	"o_forge": ["Bring the three jewels to Kavian in Zabol", "سه گوهر را نزدِ کاویان در زابل ببر"],
	"o_descend": ["Raise the banner at the Gate of Damavand and go down to Zahhak", "درفش را پیشِ دروازهٔ دماوند برافراز و به سراغِ ضحاک پایین برو"],
	"o_bound": ["Zahhak is bound — return to Zal", "ضحاک دوباره در بند است — نزدِ زال برگرد"],
	# ---- toasts
	"t_road": ["The road east of the Ashen Peaks is open — to Damavand.", "راهِ شرقِ قله‌های خاکستر باز شد — به سوی دماوند."],
	"t_jewel": ["Jewel of the banner: %s (%d/3)", "گوهرِ درفش: %s (%d/۳)"],
	"t_all": ["All three jewels — bring them to Kavian in Zabol", "هر سه گوهر — نزدِ کاویان در زابل ببرشان"],
	"t_banner": ["Derafsh-e Kaviani: the banner is yours — the Gate of Damavand will open for it", "درفشِ کاویانی از آنِ توست — دروازهٔ دماوند برایش باز می‌شود"],
	"t_bound": ["Zahhak is bound! Return to Zal.", "ضحاک دوباره در بند است — نزدِ زال برگرد."],
	"t_altar": ["An altar burns (%d/3) — light the others before it dies!", "آتشدانی روشن شد (%d/۳) — پیش از خاموش شدنش بقیه را روشن کن!"],
	"t_altar_out": ["The altar's fire dies.", "آتشِ آتشدان خاموش شد."],
	"t_temple": ["The three fires burn together. The temple opens its heart.", "سه آتش با هم می‌سوزند. آتشکده دلش را می‌گشاید."],
	"t_altar_cold": ["A cold altar. Strike it, or bring fire.", "آتشدانی سرد. ضربه‌ای بزن یا آتش بیاور."],
	"t_qtask": ["Qaren's task: the serpent guards (%d of %d)", "کارِ قارن: روزبانانِ ضحاک (%d از %d)"],
	"t_guard": ["Serpent guards %d/%d", "روزبانانِ ضحاک %d/%d"],
	"t_guards_done": ["Ten serpent guards — return to Qaren", "ده پاسدارِ ماردوش — نزدِ قارن برگرد"],
	"t_gold": ["+%d gold", "+%d سکه"],
	# ---- gates
	"g_road": ["Ash and fallen rock choke the road east.\n(Kavian the Smith may know more)", "خاکستر و سنگِ ریخته راهِ شرق را بسته است.\n(شاید کاویانِ آهنگر چیزی بداند)"],
	"g_gate": ["The Gate of Damavand is sealed. A banner is carved on it.\n(Only the Derafsh-e Kaviani opens it)", "دروازهٔ دماوند مهر شده است. نقشِ یک درفش رویش کنده‌اند.\n(فقط درفشِ کاویانی بازش می‌کند)"],
	# ---- Kaveh
	"ka1": ["Ember-bearer — my forge-fire burned black last night, and the old chest of my fathers shook by itself.", "اخگردار — دیشب آتشِ کوره‌ام سیاه شد، و صندوقِ کهنهٔ پدرانم خودبه‌خود لرزید."],
	"ka2": ["When the Dragon of Kashaf fell, the mountain answered. Damavand is smoking. Beneath it lies Zahhak, the serpent-shouldered king, bound in chains by Fereydun.", "وقتی اژدهای کشف‌رود افتاد، کوه جواب داد. دماوند دود می‌کند. زیرِ آن ضحاکِ ماردوش خفته، همان که فریدون به زنجیرش کشید."],
	"ka3": ["The cracks in his chains have reached the last link. His serpent guards already walk the slopes, and Kondrow, his steward, has woken with them.", "ترک‌های زنجیرش به واپسین حلقه رسیده‌اند. روزبانانِ ضحاک روی دامنه راه می‌روند و کُندرو، پیشکارش، هم با آن‌ها بیدار شده."],
	"ka4": ["My forefather Kaveh raised his leather apron on a spear against Zahhak — the Derafsh-e Kaviani. Its leather is still in my chest, but its three jewels were lost on the mountain.", "نیای من کاوه پیش‌بندِ چرمی‌اش را بر سرِ نیزه کرد و در برابرِ ضحاک برخاست — درفشِ کاویانی. چرمش هنوز در صندوقِ من است، اما سه گوهرش روی کوه گم شدند."],
	"ka5": ["Bring me the three jewels and I will raise the banner again. The road east of the Ashen Peaks leads to Damavand. Old Qaren keeps watch there — Kaveh's own son, who stood beside Fereydun the day Zahhak was bound.", "سه گوهر را برایم بیاور تا درفش را دوباره برافرازم. راهِ شرقِ قله‌های خاکستر به دماوند می‌رسد. قارنِ پیر آن‌جا دیده‌بانی می‌کند — پسرِ خودِ کاوه، که روزِ بستنِ ضحاک کنارِ فریدون ایستاده بود."],
	"kj": ["%d of the three jewels. The banner waits for the rest.", "%d گوهر از سه گوهر. درفش چشم‌به‌راهِ بقیه است."],
	"kj0": ["No jewel yet. The banner waits.", "هنوز گوهری نیامده؛ درفش چشم‌به‌راه است."],
	"kf1": ["The jewels of the banner... my fathers would have wept to see them.", "گوهرهای درفش... پدرانم از دیدنشان اشک می‌ریختند."],
	"kf2": ["There — the Derafsh-e Kaviani, whole again. Wherever it is raised, tyrants tremble.", "بیا — درفشِ کاویانی، دوباره کامل. هر جا برافراشته شود، ستمگران می‌لرزند."],
	"kf3": ["Raise it before the Gate of Damavand. It will open for the banner, and for no one else.", "پیشِ دروازهٔ دماوند برافرازش. فقط برای درفش باز می‌شود، نه برای هیچ‌کسِ دیگر."],
	"kd": ["Go. The mountain will not wait for us.", "برو. کوه منتظرِ ما نمی‌ماند."],
	"k_done": ["The banner stays with you, ember-bearer. Kaveh was a smith, not a king — it was always meant for hands like yours.", "درفش پیشِ تو می‌ماند، اخگردار. کاوه آهنگر بود، نه شاه — این درفش همیشه از آنِ دست‌هایی چون دستِ تو بوده است."],
	# ---- Qaren
	"q1": ["You came from Zabol? Then Kavian sent you — the last of my line who still keeps a forge. I am Qaren, son of Kaveh.", "از زابل آمدی؟ پس کاویان فرستادت — آخرینِ تبارِ من که هنوز کوره روشن نگه می‌دارد. من قارنم، پسرِ کاوه."],
	"q1b": ["I stood beside Fereydun the day we chained Zahhak to this mountain. I have kept watch on it ever since.", "روزی که ضحاک را به این کوه بستیم، کنارِ فریدون ایستاده بودم. از آن روز نگهبانِ این کوهم."],
	"q2": ["Zahhak's serpent guards come down the slopes every night. Bring ten of them down, and I will give you what I found in the ash: a jewel of the banner.", "روزبانانِ ضحاک هر شب از دامنه پایین می‌آیند. ده‌تایشان را از پا دربیاور تا آنچه را در خاکستر پیدا کردم به تو بدهم: گوهری از درفش."],
	"q3": ["The second jewel hangs on Kondrow's chain. The steward holds the ruined terrace to the north-west.", "گوهرِ دوم به گردنبندِ کُندرو آویخته است. پیشکار ایوانِ ویرانِ شمال‌غرب را در دست دارد."],
	"q4": ["The third lies in the old fire temple to the south-east. Its three altars have been cold for a thousand years — light them together, and the temple may give it up.", "سومی در آتشکدهٔ کهنِ جنوب‌شرق است. سه آتشدانش هزار سال است سردند — هر سه را با هم روشن کن، شاید آتشکده آن را پس بدهد."],
	"qp": ["Serpent guards: %d of %d. Keep at it.", "روزبانانِ ضحاک: %d از %d. ادامه بده."],
	"qdone": ["Ten! The slopes will sleep tonight. Here — the jewel, as I promised.", "ده‌تا! امشب دامنه آرام می‌خوابد. بگیر — گوهر، همان‌طور که قول دادم."],
	"q_after": ["The Gate of Damavand opens only for the banner. Make it whole.", "دروازهٔ دماوند فقط برای درفش باز می‌شود. کاملش کن."],
	"q_bound": ["The mountain is quiet at last. My father Kaveh would have made songs of you.", "کوه سرانجام آرام شد. پدرم کاوه اگر بود برایت سرود می‌ساخت."],
	# ---- Sorush, when Zahhak falls
	"s1": ["Hold your blade, ember-bearer. Do not slay him.", "دست نگه دار، اخگردار. او را نکش."],
	"s2": ["So it was said to Fereydun long ago: his time is not yet. Bind him to the mountain, and let the mountain keep him.", "روزگاری به فریدون هم همین گفته شد: هنوز زمانش نرسیده. او را به کوه ببند و بگذار کوه نگهش دارد."],
	"s3": ["The chains of Damavand close again. While the banner stands in Zabol, they will hold.", "زنجیرهای دماوند دوباره بسته شدند. تا درفش در زابل برافراشته است، تاب می‌آورند."],
	"bound": ["BOUND IN DAMAVAND", "در بندِ دماوند"],
	# ---- Zal
	"e_kaveh": ["Kavian has been asking for you, ember-bearer. His forge-fire burned black last night — go to him.", "کاویان سراغت را می‌گرفت، اخگردار. دیشب آتشِ کوره‌اش سیاه شد — نزدش برو."],
	"e_hurry": ["Kaveh's banner, Damavand's chains... go, ember-bearer. The mountain will not wait.", "درفشِ کاوه، زنجیرهای دماوند... برو، اخگردار. کوه منتظر نمی‌ماند."],
	"ep1": ["Damavand is quiet. I felt the mountain sigh, like a sleeper turning over.", "دماوند آرام گرفته. حس کردم کوه آه کشید، مثلِ خفته‌ای که پهلو به پهلو شود."],
	"ep2": ["Kaveh's banner raised again, Zahhak in his chains — the old tales walk among us, and you walk with them.", "درفشِ کاوه دوباره برافراشته، ضحاک در بندِ زنجیرهایش — افسانه‌های کهن میانِ ما راه می‌روند، و تو همراهشان."],
	"ep3": ["Rest now, ember-bearer of Zabol. Whatever wakes next, Zabol knows whom to call — and what it costs.", "حالا بیاسا، اخگردارِ زابل. هر چه بعد بیدار شود، زابل می‌داند چه کسی را صدا کند — و بهایش چقدر است."],
	# ---- the end card
	"end_title": ["Chapter Three complete", "فصلِ سوم به پایان رسید"],
	"end_text": ["Zahhak sleeps in his chains again beneath Damavand, and the Derafsh-e Kaviani flies over Zabol. The poets will sing of Rostam; of you, no one. You were paid, and the world is still yours to roam.",
		"ضحاک دوباره در زنجیرهایش زیرِ دماوند خفته، و درفشِ کاویانی بر فرازِ زابل برافراشته است. شاعران از رستم خواهند سرود؛ از تو، هیچ‌کس. مزدت را گرفتی، و دنیا هنوز برای گشتن از آنِ توست."],
	# ---- in the fight
	"z_call": ["Feed, my serpents!", "بخورید، مارهایم!"],
	"z_phase": ["A thousand years I reigned — and still I am king!", "هزار سال شاهی کردم — و هنوز شاهم!"],
}

static func line(id: String) -> String:
	var p: Array = L.get(id, [id, id])
	return Game.t(str(p[0]), str(p[1]))

static func fmt(id: String, args: Array) -> String:
	var p: Array = L.get(id, [id, id])
	if Game.lang == "fa":
		var fa_args := []
		for a in args:
			fa_args.append(Game.num(a) if typeof(a) == TYPE_INT else a)
		return str(p[1]).replace("%d", "%s") % fa_args
	return str(p[0]) % args

# ---------------------------------------------------------------- state
static func st() -> Dictionary:
	var s = Game.state.get("c3", null)
	if typeof(s) != TYPE_DICTIONARY:
		s = {}
		Game.state["c3"] = s
	if not s.has("step"):
		s["step"] = ""
	if typeof(s.get("jewels", null)) != TYPE_DICTIONARY:
		s["jewels"] = {"kondrow": false, "temple": false, "qaren": false}
	if not s.has("banner"):
		s["banner"] = false
	if not s.has("altars_done"):
		s["altars_done"] = false
	if not s.has("altars_lit"):
		s["altars_lit"] = false
	if typeof(s.get("qaren", null)) != TYPE_DICTIONARY:
		s["qaren"] = {"met": false, "kills": 0, "st": "none"}
	return s

static func step() -> String:
	return str(st()["step"])

static func at_least(s: String) -> bool:
	return STEPS.find(step()) >= STEPS.find(s)

static func set_step(s: String) -> void:
	st()["step"] = s
	Game.save_game()
	Game.stats_changed.emit()

## the chapter can begin once chapter 2 is over
static func open() -> bool:
	return Game.Ch2.step() == "done"

static func qaren() -> Dictionary:
	return st()["qaren"]

static func jewels_have() -> int:
	var n := 0
	for k in JEWELS:
		if bool(st()["jewels"].get(k, false)):
			n += 1
	return n

static func next_jewel() -> String:
	for k in JEWELS:
		if not bool(st()["jewels"].get(k, false)):
			return k
	return ""

static func road_open() -> bool:
	return at_least("jewels")

static func gate_open() -> bool:
	return at_least("descend")

## the banner: more damage where it was meant to be raised
static func banner_mul() -> float:
	if bool(st().get("banner", false)) and str(Game.state.get("map", "")) in ["damavand", "zahhakcave"]:
		return BANNER_MUL
	return 1.0

# ---------------------------------------------------------------- objective, compass, news, gates
static func objective() -> String:
	if not open():
		return ""
	match step():
		"":
			return line("o_kaveh")
		"jewels":
			var o := fmt("o_jewels", [jewels_have()])
			match next_jewel():
				"kondrow":
					return o + line("o_kondrow")
				"temple":
					return o + line("o_temple")
				"qaren":
					var q := qaren()
					if not bool(q["met"]):
						return o + line("o_qaren_meet")
					if q["st"] == "ready":
						return o + line("o_qaren_back")
					return o + fmt("o_qaren", [int(q["kills"]), GUARDS_NEED])
			return o
		"forge":
			return line("o_forge")
		"descend":
			return line("o_descend")
		"bound":
			return line("o_bound")
	return ""

static func target() -> Dictionary:
	if not open():
		return {}
	var g := Game.world_graph()
	var kaveh := {"map": "village", "pos": Game._v(g.get("village", {}).get("npcs", {}).get("smith", [613, 234])), "kind": "npc"}
	var elder := {"map": "village", "pos": Game._v(g.get("village", {}).get("npcs", {}).get("elder", [443, 334])), "kind": "npc"}
	var qn := {"map": "damavand", "pos": Game._v(g.get("damavand", {}).get("npcs", {}).get("qaren", [390, 830])), "kind": "npc"}
	match step():
		"", "forge":
			return kaveh
		"bound":
			return elder
		"jewels":
			match next_jewel():
				"kondrow":
					return {"map": "damavand", "pos": Game._v(g.get("damavand", {}).get("bosses", {}).get("kondrow", [320, 260])), "kind": "boss"}
				"temple":
					return {"map": "damavand", "pos": Vector2(1145, 830), "kind": "npc"}
				"qaren":
					if not bool(qaren()["met"]) or qaren()["st"] == "ready":
						return qn
					return {}
		"descend":
			return {"map": "zahhakcave", "pos": Game._v(g.get("zahhakcave", {}).get("bosses", {}).get("zahhak", [600, 770])), "kind": "boss"}
	return {}

static func has_news(id: String) -> bool:
	match id:
		"smith":
			return open() and step() in ["", "forge"]
		"elder":
			return step() == "bound"
		"qaren":
			var q := qaren()
			return road_open() and (not bool(q["met"]) or q["st"] == "ready")
	return false

static func exit_block(to: String) -> String:
	if to == "damavand" and not road_open():
		return line("g_road")
	if to == "zahhakcave" and not gate_open():
		return line("g_gate")
	return ""

# ---------------------------------------------------------------- Kaveh
static var told := "-"

## Kaveh's lines for the chapter ([] = nothing to say about it: his shop and forge as before)
static func kaveh_lines() -> Array:
	told = "-"
	if not open():
		return []
	told = step()
	match step():
		"":
			return [line("ka1"), line("ka2"), line("ka3"), line("ka4"), line("ka5")]
		"jewels":
			return [fmt("kj", [jewels_have()]) if jewels_have() > 0 else line("kj0")]
		"forge":
			return [line("kf1"), line("kf2"), line("kf3")]
		"descend":
			return [line("kd")]
	told = "-"
	return []

## after Kaveh's lines: the toasts to show
static func kaveh_done() -> Array:
	var out := []
	if told != step():
		return out
	told = "-"
	match step():
		"":
			set_step("jewels")
			out.append(line("t_road"))
		"forge":
			st()["banner"] = true
			set_step("descend")
			Game.Ach.unlock("kaviani")
			out.append(line("t_banner"))
	return out

static func take_jewel(k: String) -> String:
	var s := st()
	if bool(s["jewels"].get(k, false)) or not at_least("jewels"):
		return ""
	s["jewels"][k] = true
	var msg := fmt("t_jewel", [line("j_" + k), jewels_have()])
	if jewels_have() >= 3 and step() == "jewels":
		s["step"] = "forge"
		msg += "\n" + line("t_all")
	Game.save_game()
	Game.stats_changed.emit()
	return msg

# ---------------------------------------------------------------- Qaren
static func qaren_lines() -> Array:
	var q := qaren()
	if not bool(q["met"]):
		return [line("q1"), line("q1b"), line("q2"), line("q3"), line("q4")]
	if q["st"] == "ready":
		return [line("qdone")]
	if at_least("bound"):
		return [line("q_bound")]
	if q["st"] == "done":
		return [line("q_after")]
	return [fmt("qp", [int(q["kills"]), GUARDS_NEED])]

static func qaren_done() -> Array:
	var q := qaren()
	var out := []
	if not bool(q["met"]):
		q["met"] = true
		if q["st"] == "none":
			q["st"] = "active" if int(q["kills"]) < GUARDS_NEED else "ready"
	elif q["st"] == "ready":
		q["st"] = "done"
		var g := int(round(200.0 * Game.gold_mul()))
		Game.state["gold"] = int(Game.state.get("gold", 0)) + g
		out.append(fmt("t_gold", [g]))
		var m := take_jewel("qaren")
		if m != "":
			out.append(m)
	Game.save_game()
	Game.stats_changed.emit()
	return out

# ---------------------------------------------------------------- bosses, kills, the temple
static func on_boss(type: String) -> String:
	var out := []
	match type:
		"kondrow":
			var m := take_jewel("kondrow")
			if m != "":
				out.append(m)
		"zahhak":
			if step() in ["jewels", "forge", "descend"]:
				st()["step"] = "bound"
			Game.Ach.unlock("zahhak")
			out.append(line("t_bound"))
	Game.save_game()
	return "\n".join(out)

## a foe falls: Qaren's count of serpent guards; returns a toast ("" = none)
static func on_kill(type: String) -> String:
	if not type in GUARDS:
		return ""
	var q := qaren()
	if not road_open() or q["st"] in ["ready", "done"]:
		return ""
	q["kills"] = min(GUARDS_NEED, int(q["kills"]) + 1)
	if not bool(q["met"]):
		return ""                # counted, but Qaren has not asked yet
	if int(q["kills"]) >= GUARDS_NEED:
		q["st"] = "ready"
		return line("t_guards_done")
	return fmt("t_guard", [int(q["kills"]), GUARDS_NEED])

## the fire temple's three altars burned together: its treasure, once (the jewel, gold, an epic accessory)
static func temple_open() -> Array:
	var s := st()
	if bool(s["altars_done"]):
		return []
	s["altars_done"] = true
	var out := [line("t_temple")]
	var g := int(round(180.0 * Game.gold_mul()))
	Game.state["gold"] = int(Game.state.get("gold", 0)) + g
	Game.Gear.grant(Game.Gear.roll("epic"))
	out.append(fmt("t_gold", [g]))
	var m := take_jewel("temple")
	if m != "":
		out.append(m)
	Game.save_game()
	Game.stats_changed.emit()
	return out

# ---------------------------------------------------------------- Zal (the elder)
static var e_told := "-"

static func elder_lines() -> Array:
	e_told = "-"
	if not open():
		return []
	e_told = step()
	match step():
		"":
			return [line("e_kaveh")]
		"bound":
			return [line("ep1"), line("ep2"), line("ep3")]
		"jewels", "forge", "descend":
			return [line("e_hurry")]
	e_told = "-"
	return []

## "end" when the epilogue was told
static func elder_done() -> String:
	if e_told != step():
		return ""
	e_told = "-"
	if step() == "bound":
		set_step("done")
		return "end"
	return ""

# ---------------------------------------------------------------- the quest log
static func log_lines() -> Array:
	var out := []
	if not open() and step() == "":
		return out
	var stt := ""
	match step():
		"":
			stt = Game.t("speak with Kavian", "با کاویان صحبت کن")
		"jewels":
			stt = Game.t("jewels %d/3" % jewels_have(), "گوهرها %s/۳" % Game.num(jewels_have()))
		"forge":
			stt = Game.t("return to Kavian", "نزدِ کاویان برگرد")
		"descend":
			stt = Game.t("the Cave of Chains", "غارِ زنجیرها")
		"bound":
			stt = Game.t("return to Zal", "نزدِ زال برگرد")
		"done":
			stt = Game.t("done", "انجام شد")
	out.append(["scroll-text" if step() != "done" else "check", line("title"), stt, step() == "done"])
	var q := qaren()
	if bool(q["met"]):
		var d: bool = q["st"] == "done"
		out.append(["check" if d else "target", line("q_qaren"), Game.t("done", "انجام شد") if d else ("%s/%s" % [Game.num(int(q["kills"])), Game.num(GUARDS_NEED)]), d])
	if bool(st()["banner"]):
		out.append(["check", line("banner"), Game.t("+12% damage on Damavand", "+۱۲٪ آسیب در دماوند"), true])
	return out
