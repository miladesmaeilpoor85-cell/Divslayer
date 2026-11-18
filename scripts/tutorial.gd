extends RefCounted
## (v0.24) Rostam's training in Zabol — the playtesters' "nine buttons and no teacher". A new Ember-bearer meets Rostam in the
## training yard on the way to the forge; he offers a short training (it can be skipped, at the start or at any point):
##   ""        not met yet (a new hero)              -> talk to Rostam: train, or skip
##   "strike"  strike the post three times
##   "heavy"   one heavy blow (hold Attack, let go)
##   "roll"    roll out of (or through) his marked blow, twice
##   "block"   take his blow on the shield, once
##   "spell"   (v0.24, playtest: "five buttons nobody teaches") the ember answers: cast a spell in the yard
##   "done"    he pays (two potions, 30 gold) and sends you to his father Zal
##   "skipped"
## Talking to Zal first starts the tale anyway; the training waits in the yard while you are new to it.
## After it, Rostam gives a word of advice for the fight ahead (hint()). State: Game.state.tut = {step, hits, rolls}.

const STEPS := ["", "strike", "heavy", "roll", "block", "spell", "sig", "done"]
const STRIKES := 3
const ROLLS := 2
const GIFT_GOLD := 30
const GIFT_POTIONS := 2

const L := {
	"name": ["Rostam", "رستم"],
	"r1": ["So you are the sell-sword the ember stuck to. I am Rostam, son of Zal.", "پس تو همان مزدوری هستی که اخگر به دستش چسبیده. من رستمم، پسرِ زال."],
	"r2": ["I have slain these divs once already. Now my blade passes through their echoes like mist; only your ember returns them to dust. Show me what your arm can do; the yard is ready.",
		"من این دیوها را یک بار کشته‌ام. اکنون تیغم از پژواکشان می‌گذرد، چنان‌که از مه. تنها اخگرِ توست که به خاکشان برمی‌گرداند. نشانم بده چه در بازو داری؛ میدانِ تمرین آماده است."],
	"o_train": ["Train with me", "با من تمرین کن"],
	"o_skip": ["I know the ways of war", "راه و رسمِ نبرد را می‌دانم"],
	"o_train_late": ["Train with me after all", "با این‌همه، با من تمرین کن"],
	"o_bye": ["Thank you, Rostam", "سپاس، رستم"],
	"o_go_on": ["Go on with the training", "تمرین را ادامه بده"],
	"o_stop": ["Enough training", "تمرین بس است"],
	"r_skip": ["Then go to my father Zal by the fountain. Come back to me any time — I'll tell you what I know of the foes ahead.",
		"پس نزدِ پدرم زال کنارِ چشمه برو. هر وقت خواستی برگرد — هر چه از دشمنانِ پیشِ رو می‌دانم می‌گویم."],
	"r_skip2": ["Then go where the tale calls you. Come back any time — I'll tell you what I know of the foes ahead.",
		"پس برو هر جا که داستان صدایت می‌زند. هر وقت خواستی برگرد — هر چه از دشمنانِ پیشِ رو می‌دانم می‌گویم."],
	"r_mid": ["We were not finished. Shall we go on?", "هنوز تمام نشده بود. ادامه بدهیم؟"],
	# the drills
	"t_strike": ["Strike the post three times — tap Attack.", "سه بار به چوبهٔ تمرین بزن — دکمهٔ حمله را بزن."],
	"t_heavy": ["Now hold Attack until the ring fills, then let go: a heavy blow on the post.", "حالا دکمهٔ حمله را نگه دار تا حلقه پر شود، بعد رها کن: یک ضربهٔ سنگین بر چوبه."],
	"t_roll": ["When the ground glows under you, a blow is coming. Roll out of it — or through it, just as it lands. Twice.",
		"وقتی زمینِ زیرِ پایت روشن شد، ضربه‌ای در راه است. از آن بیرون غلت بزن — یا درست لحظهٔ فرود از میانش. دو بار."],
	"t_block": ["Now the shield: hold Block and take my blow on your shield.", "حالا سپر: دکمه‌اش را نگه دار و ضربه‌ام را روی سپرت بگیر."],
	"t_spell": ["The ember is yours to command too: tap the spell button that now glows, here in the yard.",
		"اخگر هم به فرمانِ توست: دکمهٔ جادو را که حالا روشن شده، همین‌جا در میدان بزن."],
	"walked": ["Roll — the Roll button!", "غلت بزن — با دکمهٔ غلت!"],
	"come_back": ["Rostam: \"The yard will wait. Come back when you are ready.\"", "رستم: «میدان همین‌جاست. هر وقت آماده بودی برگرد.»"],
	"o_spell": ["Rostam's training: cast a spell in the yard", "تمرینِ رستم: در میدان یک جادو بزن"],
	"spelled": ["The ember answers!", "اخگر پاسخ داد!"],
	# (v0.26) the last drill is the calling's own move
	"t_sig_warrior": ["Last, my own way: the lasso. Throw it — it drags a foe to your feet.", "و در پایان، راهِ خودِ من: کمند. بیندازش — دشمن را تا پیشِ پایت می‌کشد."],
	"t_sig_mage": ["Last, my father's way: the Simorgh's feather. Lay it on the fire, and the Simorgh's shadow turns the next blow from you.", "و در پایان، راهِ پدرم: پرِ سیمرغ. بر آتشش بنه تا سایهٔ سیمرغ ضربهٔ بعدی را از تو بگرداند."],
	"t_sig_rogue": ["Last, Gordafarid's way: the arrow. With it she stood before... a young man I will not name. Loosed from hiding it bites three times as deep.", "و در پایان، راهِ گردآفرید: تیر. با همین تیر پیشِ جوانی ایستاد که... نامش را نمی‌برم. از نهان که رها شود، سه‌برابر کاری‌تر است."],
	"t_sig_paladin": ["Last, Siavash's way: the walk through fire. Fire does not burn the guiltless — and does not spare the guilty.", "و در پایان، راهِ سیاوش: گذر از آتش. آتش بی‌گناه را نمی‌سوزاند — و از گناهکار نمی‌گذرد."],
	"o_sig": ["Rostam's training: use your calling's move — %s", "تمرینِ رستم: فنِ راهت را بزن — %s"],
	"good": ["Good!", "خوب است!"],
	"again": ["Again!", "دوباره!"],
	"rolled": ["Rolled clear! (%d/%d)", "بیرون غلتیدی! (%d/%d)"],
	"blocked": ["Held!", "تاب آوردی!"],
	"hit_post": ["%d/%d", "%d/%d"],
	"r_done1": ["Enough. You'll do.", "بس است. از پسش برمی‌آیی."],
	"r_parry": ["One more thing: raise the shield just before a blow lands — a perfect block staggers the foe.",
		"یک چیز دیگر: سپر را درست پیش از فرودِ ضربه بالا بیاور — دفاعِ بی‌نقص دشمن را گیج می‌کند."],
	"r_done2": ["Take these, and go to my father Zal by the fountain — he has work for an ember-bearer.",
		"این‌ها را بگیر و نزدِ پدرم زال کنارِ چشمه برو — برای یک اخگردار کار دارد."],
	"r_done2b": ["Take these. Now go — the road is waiting for an ember-bearer.", "این‌ها را بگیر. حالا برو — راه چشم‌به‌راهِ یک اخگردار است."],
	"t_gift": ["+%d gold · +%d potions", "+%d سکه، +%d معجون"],
	# objectives
	"o_meet": ["Meet Rostam in the training yard — or speak with Zal by the fountain", "نزدِ رستم در میدانِ تمرین برو — یا با زال کنارِ چشمه صحبت کن"],
	"o_strike": ["Rostam's training: strike the post (%d/%d)", "تمرینِ رستم: به چوبه بزن (%d/%d)"],
	"o_heavy": ["Rostam's training: a heavy blow on the post (hold Attack)", "تمرینِ رستم: یک ضربهٔ سنگین بر چوبه (حمله را نگه دار)"],
	"o_roll": ["Rostam's training: roll out of the glowing ground (%d/%d)", "تمرینِ رستم: از زمینِ روشن بیرون غلت بزن (%d/%d)"],
	"o_block": ["Rostam's training: hold Block as his blow falls", "تمرینِ رستم: وقتی ضربه‌اش فرود می‌آید سپر را نگه دار"],
	# his advice afterwards, by where the tale stands
	"h_default": ["Roll through a blow just as it lands and the foe staggers. Even I learned that late.", "درست لحظهٔ فرودِ ضربه از میانش غلت بزن تا دشمن گیج شود. من هم دیر یادش گرفتم."],
	"h_q1": ["On my sixth labour I tore Arzhang's head from his shoulders. His echo hides behind grave pillars when it weakens: break them — or let its charge strike one.",
		"در خوانِ ششم سرِ ارژنگ را از تن کندم. پژواکش وقتی سست می‌شود پشتِ ستون‌های گورگاه پنهان می‌شود: بشکنشان — یا بگذار یورشش به یکی بخورد."],
	"h_q2": ["The King of Mazandaran turned to stone before my eyes, and I carried that stone to our camp. His echo wears molten armour: wait until it vents, then strike the open core.",
		"شاهِ مازندران پیشِ چشمم سنگ شد و آن سنگ را تا لشکرگاه به دوش کشیدم. پژواکش زرهِ مذاب دارد: صبر کن تا گدازه‌اش را بیرون بدهد، بعد به دلِ بی‌زره‌اش بزن."],
	"h_q3": ["On my fourth labour the Sorceress sat down beside me as a fair maid. I spoke the name of God, her face turned black, and my lasso did not let her go. Her echo dives into the mud and bursts out under you: keep moving, and burn her eggs before they hatch.",
		"در خوانِ چهارم زنِ جادو چون دختری زیبا کنارم نشست. نامِ یزدان را که بردم چهره‌اش سیاه شد و کمندم امانش نداد. پژواکش در گل فرو می‌رود و از زیرِ پایت بیرون می‌زند: یک‌جا نمان، و تخم‌هایش را پیش از آن‌که سر باز کنند بسوزان."],
	"h_ch2": ["The White Div was my seventh labour, and his liver gave Kavus back his sight; Akvan once hurled me into the sea. The White Div's echo makes twins of ice — break both fast. The Dragon dives on its shadow: move, then strike as it rises.",
		"دیو سپید خوانِ هفتمم بود و جگرش چشمِ کاووس را روشن کرد؛ اکوان هم روزی مرا به دریا انداخت. پژواکِ دیو سپید از یخ همزاد می‌سازد — هر دو را زود بشکن. اژدها روی سایه‌اش فرود می‌آید: کنار برو، وقتی برخاست بزن."],
	"h_ch3": ["Zahhak is no echo — he is the thing itself, and Fereydun's chains are failing. His serpents bite along marked lanes: step aside, then strike. Fire hurts him, and the banner is with you.",
		"ضحاک پژواک نیست — خودِ اوست، و بندهای فریدون سست شده. مارهایش در مسیرهای نشان‌دار نیش می‌زنند: کنار برو، بعد بزن. آتش آزارش می‌دهد و درفش با توست."],
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

static func st() -> Dictionary:
	var s = Game.state.get("tut", null)
	if typeof(s) != TYPE_DICTIONARY:
		# a hero from before v0.24 (the tale already begun) never meets the training as a task
		s = {"step": "" if Game.q(1) == "not_started" else "skipped", "hits": 0, "rolls": 0}
		Game.state["tut"] = s
	return s

static func step() -> String:
	return str(st().get("step", ""))

static func set_step(s: String) -> void:
	st()["step"] = s
	Game.save_game()
	Game.stats_changed.emit()

## a drill in progress
static func active() -> bool:
	return step() in ["strike", "heavy", "roll", "block", "spell", "sig"]

## (v0.26, playtest: "I left the yard half-way; the drill stayed my objective in the forest and hid Arzhang's quest") the
## hero has walked off in the middle of a drill (the yard sets it; any other map counts too): the drill waits, and the
## objective, the compass and the glowing button go back to the tale until he returns
static var away := false

static func drilling() -> bool:
	return active() and not away and str(Game.state.get("map", "village")) == "village"

## Rostam has not been met yet: he offers the training (even to a hero who went to Zal first)
static func fresh() -> bool:
	return step() == ""

## the training is the objective (a new hero, before the tale has begun)
static func offered() -> bool:
	return fresh() and Game.q(1) == "not_started"

## (v0.25, both testers: "nine fighting buttons in a safe village from the first second") until the hero has left Zabol
## once (or is past level 1), the pad shows only attack, roll, shield and potion — and the spell Rostam's last drill asks for
static func pad_open() -> bool:
	if bool(Game.state.get("pad_all", false)):
		return true
	if Game.lvl() > 1 or str(Game.state.get("map", "village")) != "village":
		Game.state["pad_all"] = true
		return true
	return false

## the touch button the current drill asks for (the pad makes it glow and never fades it)
static func teaches() -> String:
	if not drilling():
		return ""
	match step():
		"strike", "heavy":
			return "attack"
		"roll":
			return "dodge"
		"block":
			return "block"
		"spell":
			return "skill1"
		"sig":
			return "shove"
	return ""

## (v0.24, playtest: "after Zal's quest Rostam has the right advice for Arzhang — if you happen to walk back") a "!" over
## him when the tale has moved on since his last word
static func has_news() -> bool:
	return fresh() or active() or (step() in ["done", "skipped"] and str(st().get("told", "")) != hint_key())

static func told() -> void:
	if str(st().get("told", "")) != hint_key():
		st()["told"] = hint_key()
		Game.stats_changed.emit()

## his parting words: to Zal if the tale has not begun, else onward
static func skip_line() -> String:
	return line("r_skip") if Game.q(1) == "not_started" else line("r_skip2")

static func done_line() -> String:
	return line("r_done2") if Game.q(1) == "not_started" else line("r_done2b")

static func objective() -> String:
	if active() and not drilling():
		return ""
	match step():
		"":
			return line("o_meet") if Game.q(1) == "not_started" else ""
		"strike":
			return fmt("o_strike", [int(st().get("hits", 0)), STRIKES])
		"heavy":
			return line("o_heavy")
		"roll":
			return fmt("o_roll", [int(st().get("rolls", 0)), ROLLS])
		"block":
			return line("o_block")
		"spell":
			return line("o_spell")
		"sig":
			return fmt("o_sig", [Game.Skills.sig_name()])
	return ""

static func target() -> Dictionary:
	if not (offered() or drilling()):
		return {}
	var g := Game.world_graph()
	return {"map": "village", "pos": Game._v(g.get("village", {}).get("npcs", {}).get("rostam", [565, 178])), "kind": "npc"}

static func start() -> void:
	st()["hits"] = 0
	st()["rolls"] = 0
	set_step("strike")

static func skip() -> void:
	told()
	set_step("skipped")

## the training finished: his gift. Returns the toast.
static func finish() -> String:
	told()
	set_step("done")
	Game.state["gold"] = int(Game.state.get("gold", 0)) + GIFT_GOLD
	Game.state["potions"] = int(Game.state.get("potions", 0)) + GIFT_POTIONS
	Game.save_game()
	Game.stats_changed.emit()
	return fmt("t_gift", [GIFT_GOLD, GIFT_POTIONS])

## Rostam's word for the fight ahead
static func hint() -> String:
	return line(hint_key())

static func hint_key() -> String:
	if Game.Ch3.open() and Game.Ch3.step() != "done":
		return "h_ch3"
	if Game.Ch2.open() and Game.Ch2.step() != "done":
		return "h_ch2"
	if Game.q(1) == "active":
		return "h_q1"
	if Game.q(2) == "active":
		return "h_q2"
	if Game.q(3) == "active":
		return "h_q3"
	return "h_default"
