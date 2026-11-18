extends RefCounted
## Chapter 2 — "The Sleeper Beneath" (v0.19). All of it is mine: the HTML game had the Dragon of Kashaf's picture and numbers,
## Sorush's first line and the idea of a sealed chamber opened by a Wyrm Key, but no story around them.
##
## (v0.26: the three bosses of Zal's quests are echoes coiled around three seals) The First Smiths set the seals to keep the Dragon of Kashaf asleep in
## the hollow beneath the Crystal Sanctum. With them gone the Wyrm stirs.
##   ""        Elder's quests not finished, or finished and not yet told (the Elder tells it: the tremor)
##   "keeper"  seek Sorush in the Sanctum
##   "shards"  recover the three shards of the Wyrm Key: Judgement (the White Div), Frost (Akvan the Div in
##             the Hoarfrost Vale, east of the Sanctum) and Memory (Sorush's vault, sealed in rimeglass: heavy blows
##             or fire break it). Sorush's word opens the way east and loosens the vault.
##   "forge"   bring the three to Sorush: the Wyrm Key; the sealed door behind the Judge's seat opens
##   "descend" go down into the Wyrm's Hollow and slay the Dragon of Kashaf
##   "slain"   return to Zal: the epilogue and the end of the chapter
##   "done"
## Side: Akvan's frost-heart -> Jamshid forges the Frostreaver and the Glacial Aegis. Hom the trapper's camp in the Vale:
## "Wolves of the Vale" (8 frost wolves) and "The Lost Expedition" (3 journal pages in the snow), and his little shop.
## State: Game.state.c2 = {step, shards: {judgement, frost, memory}, heart: "none"|"have"|"forged", vault: [broken cells],
##        vault_open, hesk: {met, wolves, wolves_st, pages, pages_st}}

const SHARDS := ["judgement", "frost", "memory"]
const WOLVES_NEED := 8
const PAGES := 3
const STEPS := ["", "keeper", "shards", "forge", "descend", "slain", "done"]

const L := {
	# ---- names
	"title": ["The Sleeper Beneath", "خفته در ژرفا"],
	"s_judgement": ["Shard of Judgement", "تکهٔ داوری"],
	"s_frost": ["Shard of Frost", "تکهٔ یخ"],
	"s_memory": ["Shard of Memory", "تکهٔ یاد"],
	"key": ["the Wyrm Key", "کلیدِ اژدها"],
	"hesk": ["Hom the Trapper", "هومِ تله‌گذار"],
	"q_wolves": ["Wolves of the Vale", "گرگ‌های دره"],
	"q_pages": ["The Lost Expedition", "سفرِ گم‌شده"],
	"q_heart": ["Frost-steel", "فولادِ یخ"],
	"stirs": ["THE WYRM STIRS!", "اژدها می‌جنبد!"],
	# ---- objectives
	"o_elder": ["Speak with Zal — the ground is trembling", "با زال صحبت کن — زمین می‌لرزد"],
	"o_keeper": ["Seek Sorush in the Crystal Sanctum (north of the Ashen Peaks)", "سروش را در معبدِ بلورین پیدا کن (شمالِ قله‌های خاکستر)"],
	"o_shards": ["Recover the shards of the Wyrm Key (%d/3)", "تکه‌های کلیدِ اژدها را پس بگیر (%s/۳)"],
	"o_judgement": [": the White Div's echo, in the Sanctum", ": پژواکِ دیو سپید، در معبد"],
	"o_frost": [": Akvan's echo, in the Hoarfrost Vale (east of the Sanctum)", ": پژواکِ اکوان دیو، در درهٔ یخ‌بندان (شرقِ معبد)"],
	"o_memory": [": Sorush's frozen vault (north-east corner of the Sanctum)", ": خزانهٔ یخ‌زدهٔ سروش (گوشهٔ شمال‌شرقیِ معبد)"],
	"o_forge": ["Bring the three shards to Sorush", "سه تکه را نزدِ سروش ببر"],
	"o_descend": ["Descend into the Wyrm's Hollow and slay the Dragon of Kashaf", "به مغاکِ اژدها برو و اژدهای کشف‌رود را بکش"],
	"o_slain": ["The Wyrm is slain — return to Zal", "اژدها کشته شد — نزدِ زال برگرد"],
	# ---- toasts
	"t_east": ["The rimeglass in the east passage has thinned — the Hoarfrost Vale is open", "یخِ بلورینِ گذرگاهِ شرقی نازک شد — درهٔ یخ‌بندان باز است"],
	"t_shard": ["%s recovered (%d/3)", "%s به دست آمد (%s/۳)"],
	"t_all": ["All three shards — bring them to Sorush", "هر سه تکه — نزدِ سروش ببرشان"],
	"t_heart": ["Akvan's frost-heart — the Shade of Jamshid could forge with it", "قلبِ یخیِ اکوان — روانِ جمشید می‌تواند با آن چیزی بسازد"],
	"t_key": ["The Wyrm Key is whole — the sealed door in the Sanctum is open", "کلیدِ اژدها کامل شد — درِ مُهرشدهٔ معبد باز است"],
	"t_forged": ["Frostreaver (+46 ATK) and Glacial Aegis (+20 DEF) forged!", "تیغِ یخ‌دَر (+۴۶ حمله) و جوشنِ یخین (+۲۰ دفاع) ساخته شد!"],
	"t_slain": ["The Dragon of Kashaf is slain! Return to Zal.", "اژدهای کشف‌رود کشته شد! نزدِ زال برگرد."],
	"t_wolf": ["Frost wolves: %d/%d", "گرگ‌های یخ‌زده: %s/%s"],
	"t_wolves_done": ["Wolves of the Vale — return to Hom", "گرگ‌های دره — نزدِ هوم برگرد"],
	"t_page": ["A frozen journal page (%d/3)", "برگه‌ای یخ‌زده از دفترچه (%s/۳)"],
	"t_pages_done": ["All three pages — bring them to Hom", "هر سه برگه — نزدِ هوم ببر"],
	"t_vault_shut": ["Ancient rimeglass. Your blow does not even scratch it.", "یخِ بلورینِ کهن. از ضربه‌ات خراشی هم برنمی‌دارد."],
	"t_vault_crack": ["The rimeglass cracks!", "یخِ بلورین ترک برداشت!"],
	"t_vault_heavy": ["Heavy blows and fire break rimeglass", "ضربه‌های سنگین و آتش یخِ بلورین را می‌شکنند"],
	"t_vault_gold": ["+%d gold", "+%s سکه"],
	# ---- gates
	"g_east": ["A wall of rimeglass seals the eastern passage.\n(Sorush may know more)", "دیواری از یخِ بلورین گذرگاهِ شرقی را بسته است.\n(شاید سروش چیزی بداند)"],
	"g_door": ["A sealed door, cold as the grave. Its lock is shaped like a wyrm's eye.\n(It needs the Wyrm Key)", "دری مُهرشده، سرد مثلِ گور. قفلش شکلِ چشمِ اژدهاست.\n(کلیدِ اژدها لازم است)"],
	# ---- Zal
	"e1": ["Ember-bearer... you feel it too? The ground has not stopped trembling since the Sorceress's echo fell to dust.", "اخگردار... تو هم حسش می‌کنی؟ از آن روز که پژواکِ زنِ جادو خاک شد، زمین یک لحظه از لرزیدن نایستاده."],
	"e2": ["I fear the echoes did not rise where they did by chance. The crypt, the peak, the bog — three old seals lie there, and each echo had coiled itself around one.", "می‌ترسم آن پژواک‌ها بی‌سبب در آن سه جا سر برنیاورده باشند. سرداب، قله، مرداب — سه مُهرِ کهن آن‌جاست، و هر پژواک دورِ یکی چنبره زده بود."],
	"e3": ["The First Smiths set those seals to keep something asleep beneath the Crystal Sanctum: the Dragon of Kashaf.", "آهنگرانِ نخستین آن مُهرها را نهادند تا چیزی را زیرِ معبدِ بلورین در خواب نگه دارند: اژدهای کشف‌رود."],
	"e4": ["The echoes had gnawed the seals hollow; when they fell to dust, the seals fell with them. Now the Wyrm stirs. Go to the Sanctum — Sorush remembers what we have forgotten.", "پژواک‌ها مُهرها را از درون خورده بودند؛ وقتی خاک شدند، مُهرها هم با آن‌ها فرو ریختند. حالا اژدها می‌جنبد. به معبد برو — سروش چیزهایی را به یاد دارد که ما فراموش کرده‌ایم."],
	"e_wait": ["Sorush waits in the Crystal Sanctum, north of the Ashen Peaks.", "سروش در معبدِ بلورین منتظر است، شمالِ قله‌های خاکستر."],
	"e_hurry": ["The tremors grow worse, ember-bearer. Do not tarry.", "لرزه‌ها بدتر می‌شوند، اخگردار. درنگ نکن."],
	"ep1": ["The ground is still. For the first time in my long life, I cannot hear the mountain breathing.", "زمین آرام گرفته. برای نخستین بار در عمرِ درازم، صدای نفس کشیدنِ کوه را نمی‌شنوم."],
	"ep2": ["The echoes, the Wyrm, the First Flame... all of it ended by one ember-bearer from Zabol.", "پژواک‌ها، اژدها، نخستین شعله... همه‌اش به دستِ یک اخگردار از زابل تمام شد."],
	"ep3": ["The bards will make new songs — and put Rostam's name in them. Rest now, ember-bearer — the Vale, the Forge and the shrines are yours to wander.", "خنیاگران ترانه‌های تازه می‌سازند — و نامِ رستم را در آن‌ها می‌گذارند. حالا بیاسا، اخگردار — دره، کوره و زیارتگاه‌ها از آنِ تو هستند تا در آن‌ها بگردی."],
	# ---- Sorush
	"k0": ["The memories here are restless.", "یادهای این‌جا بی‌قرارند."],
	"k0b": ["One day I will show you what they remember.", "روزی نشانت می‌دهم که چه به یاد دارند."],
	"k1": ["I am Sorush — keeper of battles past.", "من سروشم — نگهبانِ یادِ نبردهای گذشته."],
	# (v0.24, the critic: "Sam slew the Dragon of Kashaf", and two pages that disagreed) one tale, in order
	"k2": ["The songs are true: Sam, Zal's father, struck the Dragon of Kashaf down with his ox-headed mace. But a wyrm of Kashaf does not die of one blow. The First Smiths chained its sleeping body in the hollow beneath this hall, and broke the key in three.",
		"سرودها راست می‌گویند: سام، پدرِ زال، با گرزِ گاوسر اژدهای کشف‌رود را از پا درآورد. اما اژدهای کشف‌رود با یک زخم نمی‌میرد. آهنگرانِ نخستین پیکرِ خفته‌اش را در مغاکِ زیرِ این تالار به بند کشیدند و کلیدش را سه تکه کردند."],
	"k3": ["The White Div's echo took this hall from me, and holds one shard in its fist. Another the Smiths sealed in the ice of the Hoarfrost Vale to the east; the echo of Akvan the Div has closed its chest around it.", "پژواکِ دیو سپید این تالار را از من گرفت و یک تکه را در مشت دارد. تکهٔ دیگر را آهنگران در یخِ درهٔ یخ‌بندان مُهر کردند، شرقِ این‌جا؛ پژواکِ اکوان دیو آن را در سینه‌اش فرو برده است."],
	"k4": ["The third they left with me, sealed in rimeglass in my vault. I have loosened its weave — strike it hard and it will break. The way east is open too.", "سومی را نزدِ من گذاشتند، مُهرشده در یخِ بلورین، در خزانه‌ام. بافتش را سست کرده‌ام — محکم بزنی، می‌شکند. راهِ شرق هم باز شد."],
	"k5": ["Bring me all three. I will mend the Wyrm Key, and you will go down and end what the Smiths only put to sleep.", "هر سه را برایم بیاور. کلیدِ اژدها را دوباره یکی می‌کنم، و تو پایین می‌روی تا کاری را تمام کنی که آهنگران فقط به خواب سپردند."],
	"k_arb": ["You have already returned the White Div's echo to dust. Its shard came back to me — one of the three is ours.", "تو پژواکِ دیو سپید را پیش‌تر به خاک برگردانده‌ای. پژواک که فرو ریخت، تکه‌اش نزدِ من برگشت — یکی از سه تکه از آنِ ماست."],
	"k_tip": ["Jamshid's forge and the shrines' sigils will harden you for what waits below.", "کورهٔ جمشید و نشان‌های زیارتگاه‌ها تو را برای آنچه پایین منتظر است سخت‌جان‌تر می‌کنند."],
	"k_have": ["Shards recovered: %d of 3.", "تکه‌های به‌دست‌آمده: %s از ۳."],
	"k_need_judgement": ["The White Div's echo still keeps its shard. It sits above us, at the head of the hall.", "دیو سپید هنوز تکه‌اش را نگه داشته. بالای سرِ ما نشسته، در صدرِ تالار."],
	"k_need_frost": ["Akvan's echo sleeps in the heart of the Hoarfrost Vale, beyond the east passage.", "اکوان در دلِ درهٔ یخ‌بندان خفته، آن‌سوی گذرگاهِ شرقی."],
	"k_need_memory": ["My vault is in the north-east corner. Heavy blows, or fire.", "خزانه‌ام در گوشهٔ شمال‌شرقی است. ضربهٔ سنگین، یا آتش."],
	"kf1": ["Judgement, frost and memory — the three are one again.", "داوری، یخ و یاد — آن سه دوباره یکی شدند."],
	"kf2": ["Here: the Wyrm Key. The sealed door behind the Judge's seat will answer to it.", "بگیر: کلیدِ اژدها. درِ مُهرشدهٔ پشتِ جایگاهِ داور به آن پاسخ می‌دهد."],
	"kf3": ["The Wyrm breathes a cold that stops the heart. Go with your best steel — and come back.", "اژدها سرمایی می‌دمد که دل را از تپش می‌اندازد. با بهترین فولادت برو — و برگرد."],
	"k_go": ["The Wyrm waits below. Whatever happens, I will remember you.", "اژدها پایین منتظر است. هرچه پیش بیاید، تو را به یاد خواهم داشت."],
	"k_done": ["The Wyrm is a memory now. I will keep it — and you.", "اژدها حالا فقط یک یاد است. نگهش می‌دارم — و تو را هم."],
	# ---- Jamshid and the frost-heart
	"b1": ["Is that... a div's heart? Ice that has never thawed, not since the first age.", "این... قلبِ یک دیو است؟ یخی که از عصرِ نخست تا حالا آب نشده."],
	"b2": ["Hold still. Frost-steel is forged cold — I have waited an age to try it.", "تکان نخور. فولادِ یخ را سرد می‌کوبند — روزگاری دراز چشم‌به‌راهِ چنین روزی بودم."],
	"b3": ["The Frostreaver, and the Glacial Aegis. Nothing that breathes frost will bite through these.", "تیغِ یخ‌دَر، و جوشنِ یخین. هیچ دمِ یخینی از این دو نمی‌گذرد."],
	"b_more": ["Your blade and your armour are already better than this frost-steel. Keep the heart — it is a fine trophy.", "سلاح و زره‌ات همین حالا از این فولادِ یخ بهترند. قلب را نگه دار — یادگارِ خوبی است."],
	# ---- Hom the trapper
	"h1": ["Easy, stranger. Not many walk the Vale and keep their toes.", "آرام، غریبه. کم کسی از این دره رد می‌شود و انگشت‌های پایش سالم می‌ماند."],
	"h2": ["Name's Hom. I trap, I trade, and I mind my fire. The wolves have gone wild since the ground started shaking.", "اسمم هوم است. تله می‌گذارم، داد و ستد می‌کنم و حواسم به آتشم هست. از وقتی زمین لرزیدن گرفته، گرگ‌ها وحشی شده‌اند."],
	"h3": ["Thin the packs for me — eight of them — and I'll make it worth your while.", "گله‌ها را برایم کم کن — هشت تا — جبران می‌کنم."],
	"h4": ["And if you find pages of a journal frozen in the snow... bring them. My brother led an expedition here. He never came back.", "و اگر برگه‌های یک دفترچه را یخ‌زده لای برف پیدا کردی... برایم بیاور. برادرم گروهی را به این دره آورد. هیچ‌وقت برنگشت."],
	"h5": ["Need potions? I keep a few for travellers who pay.", "معجون لازم داری؟ چندتایی برای مسافرهایی که پول می‌دهند نگه می‌دارم."],
	"h_prog": ["Wolves: %d of 8 · Pages: %d of 3. Warm your hands, then go on.", "گرگ‌ها: %s از ۸، برگه‌ها: %s از ۳. دست‌هایت را گرم کن، بعد برو."],
	"h_w1": ["Eight wolves fewer. The nights are mine again — take this, with my thanks.", "هشت گرگ کمتر. شب‌ها دوباره مالِ من است — این را بگیر، با سپاس."],
	"h_p1": ["His hand... this is his hand. So he reached the door of the Hollow.", "دست‌خطِ اوست... این دست‌خطِ اوست. پس تا درِ مغاک رسیده بود."],
	"h_p2": ["He wrote that the Wyrm only dreams while its seals hold. He was right, wasn't he.", "نوشته بود اژدها فقط تا وقتی مُهرهایش برجاست در خواب است. حق با او بود، نه؟"],
	"h_p3": ["Take his compass charm. He'd want it to go where he couldn't.", "طلسمِ قطب‌نمایش را بگیر. دلش می‌خواست این به جایی برسد که خودش نرسید."],
	"h_done": ["Mind the ice, friend. And if you see my brother's ghost down there... tell him I kept the fire lit.", "مراقبِ یخ باش، دوستِ من. و اگر آن پایین روحِ برادرم را دیدی... بگو آتش را روشن نگه داشتم."],
	# ---- the journal pages
	"page_title": ["A frozen journal page", "برگه‌ای یخ‌زده از دفترچه"],
	"page1": ["Day 9. The wolves follow us now, white as the snow. Mehran swears the mountain hums at night, like something breathing under the ice.", "روزِ نهم. گرگ‌ها حالا دنبالمان می‌آیند، سفید مثلِ برف. مهران سوگند می‌خورد که کوه شب‌ها زمزمه می‌کند، مثلِ چیزی که زیرِ یخ نفس می‌کشد."],
	"page2": ["Day 14. The old watch-post. The First Smiths kept a garrison here — to watch the Sanctum, not the road. Their carvings show three seals and a sleeping wyrm.", "روزِ چهاردهم. پاسگاهِ قدیمی. آهنگرانِ نخستین این‌جا پادگانی داشتند — برای پاییدنِ معبد، نه جاده. کنده‌کاری‌هایشان سه مُهر و اژدهایی خفته را نشان می‌دهد."],
	"page3": ["Day 20. Akvan's echo prowls the heart of the vale, and in its chest a shard of the key glows. The Wyrm only dreams while its seals hold. If they break... God keep Zabol.", "روزِ بیستم. پژواکِ اکوان در دلِ دره می‌گردد و در سینه‌اش تکه‌ای از کلید می‌درخشد. اژدها فقط تا وقتی مُهرهایش برجاست خواب است. اگر بشکنند... یزدان زابل را نگه دارد."],
	# ---- the end of the chapter
	"end_title": ["Chapter Two complete", "فصلِ دوم به پایان رسید"],
	"end_text": ["The Dragon of Kashaf is dead at last, and Zabol breathes again. The world is still yours: the Vale, the Forge, the shrines, the Trial and the Bounty Board.",
		"اژدهای کشف‌رود این بار به‌راستی مُرد و زابل دوباره نفس می‌کشد. دنیا هنوز از آنِ توست: دره، کوره، زیارتگاه‌ها، میدانِ آزمون و تابلوی قراردادها."],
	"end_thanks": ["Thank you for playing Divslayer.", "سپاس که «دیوکُش» را بازی کردی."],
	"end_go": ["Continue", "ادامه"],
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
		return str(p[1]) % fa_args
	return str(p[0]) % args

# ---------------------------------------------------------------- state
static func st() -> Dictionary:
	var s = Game.state.get("c2", null)
	if typeof(s) != TYPE_DICTIONARY:
		s = {}
		Game.state["c2"] = s
	if not s.has("step"):
		s["step"] = ""
	if typeof(s.get("shards", null)) != TYPE_DICTIONARY:
		s["shards"] = {"judgement": false, "frost": false, "memory": false}
	if not s.has("heart"):
		s["heart"] = "none"
	if typeof(s.get("vault", null)) != TYPE_ARRAY:
		s["vault"] = []
	if not s.has("vault_open"):
		s["vault_open"] = false
	if typeof(s.get("hesk", null)) != TYPE_DICTIONARY:
		s["hesk"] = {"met": false, "wolves": 0, "wolves_st": "none", "pages": 0, "pages_st": "none"}
	return s

static func step() -> String:
	return str(st()["step"])

static func at_least(s: String) -> bool:
	return STEPS.find(step()) >= STEPS.find(s)

static func set_step(s: String) -> void:
	st()["step"] = s
	Game.save_game()
	Game.stats_changed.emit()

## the chapter can begin: Zal's three quests are done
static func open() -> bool:
	return Game.q(1) == "done" and Game.q(2) == "done" and Game.q(3) == "done"

static func shards_have() -> int:
	var n := 0
	for k in SHARDS:
		if bool(st()["shards"].get(k, false)):
			n += 1
	return n

static func hesk() -> Dictionary:
	return st()["hesk"]

## the way east (the Vale) and the vault open with Sorush's word
static func east_open() -> bool:
	return at_least("shards")

static func door_open() -> bool:
	return at_least("descend")

# ---------------------------------------------------------------- objective and compass
static func objective() -> String:
	if not open():
		return ""
	match step():
		"":
			return line("o_elder")
		"keeper":
			return line("o_keeper")
		"shards":
			var o := fmt("o_shards", [shards_have()])
			var nx := next_shard()
			return o + (line("o_" + nx) if nx != "" else "")
		"forge":
			return line("o_forge")
		"descend":
			return line("o_descend")
		"slain":
			return line("o_slain")
	return ""

static func next_shard() -> String:
	for k in SHARDS:
		if not bool(st()["shards"].get(k, false)):
			return k
	return ""

static func target() -> Dictionary:
	if not open():
		return {}
	var g := Game.world_graph()
	var elder := {"map": "village", "pos": Game._v(g.get("village", {}).get("npcs", {}).get("elder", [443, 334])), "kind": "npc"}
	var keeper := {"map": "sanctum", "pos": Game._v(g.get("sanctum", {}).get("npcs", {}).get("keeper", [613, 534])), "kind": "npc"}
	match step():
		"", "slain":
			return elder
		"keeper", "forge":
			return keeper
		"shards":
			match next_shard():
				"judgement":
					return {"map": "sanctum", "pos": Game._v(g.get("sanctum", {}).get("bosses", {}).get("arbiter", [627, 204])), "kind": "boss"}
				"frost":
					return {"map": "frostvale", "pos": Game._v(g.get("frostvale", {}).get("bosses", {}).get("glaciertitan", [1170, 558])), "kind": "boss"}
				"memory":
					return {"map": "sanctum", "pos": Vector2(1140, 70), "kind": "npc"}
		"descend":
			return {"map": "wyrmhollow", "pos": Game._v(g.get("wyrmhollow", {}).get("bosses", {}).get("ancientwyrm", [650, 905])), "kind": "boss"}
	return {}

## the "!" over a villager who has something new to say
static func has_news(id: String) -> bool:
	match id:
		"elder":
			return open() and step() in ["", "slain"]
		"keeper":
			# (v0.21) once the chapter is over he has the Boss Rush and New Game+ to offer, until you have tried a run
			return step() == "keeper" or step() == "forge" or (step() == "done" and Game.Ach.stat("rush_runs") == 0 and Game.ng() == 0)
		"brann":
			return str(st()["heart"]) == "have"
		"hesk":
			var h := hesk()
			return not bool(h["met"]) or h["wolves_st"] == "ready" or h["pages_st"] == "ready"
	return false

# ---------------------------------------------------------------- gates
static func exit_block(to: String) -> String:
	if to == "frostvale" and not east_open():
		return line("g_east")
	if to == "wyrmhollow" and not door_open():
		return line("g_door")
	return ""

# ---------------------------------------------------------------- Zal
## the step whose lines the Elder has just said (elder_done acts only on what was told)
static var told := "-"

## the Elder's lines, or [] when the chapter has nothing to say through him
static func elder_lines() -> Array:
	told = "-"
	if not open():
		return []
	told = step()
	match step():
		"":
			return [line("e1"), line("e2"), line("e3"), line("e4")]
		"slain":
			return [line("ep1"), line("ep2"), line("ep3")]
		"keeper":
			return [line("e_wait")]
		"shards", "forge", "descend":
			return [line("e_hurry")]
	return []

## after the Elder's lines: returns "stirs" (the tremor), "end" (the chapter's end), or ""
static func elder_done() -> String:
	if not open() or told != step():
		return ""
	told = "-"
	match step():
		"":
			set_step("keeper")
			return "stirs"
		"slain":
			set_step("done")
			return "end"
	return ""

# ---------------------------------------------------------------- Sorush
static func keeper_lines() -> Array:
	match step():
		"", "done":
			return [line("k0"), line("k0b")] if step() == "" else [line("k_done")]
		"keeper":
			var ls := [line("k1"), line("k2"), line("k3"), line("k4"), line("k5")]
			if Game.is_defeated("arbiter"):
				ls.append(line("k_arb"))
			ls.append(line("k_tip"))
			return ls
		"shards":
			var ls2 := [fmt("k_have", [shards_have()])]
			var nx := next_shard()
			if nx != "":
				ls2.append(line("k_need_" + nx))
			return ls2
		"forge":
			return [line("kf1"), line("kf2"), line("kf3")]
		"descend", "slain":
			return [line("k_go")]
	return []

## after Sorush's lines: the toasts to show ([] = none)
static func keeper_done() -> Array:
	var out := []
	match step():
		"keeper":
			set_step("shards")
			out.append(line("t_east"))
			if Game.is_defeated("arbiter"):
				out.append(take_shard("judgement"))
			if shards_have() >= 3:
				set_step("forge")
		"forge":
			set_step("descend")
			out.append(line("t_key"))
	return out

## a shard comes to the hero: the toast line
static func take_shard(k: String) -> String:
	var s := st()
	if bool(s["shards"].get(k, false)):
		return ""
	s["shards"][k] = true
	var msg := fmt("t_shard", [line("s_" + k), shards_have()])
	if shards_have() >= 3 and step() == "shards":
		s["step"] = "forge"
		msg += "\n" + line("t_all")
	Game.save_game()
	Game.stats_changed.emit()
	return msg

# ---------------------------------------------------------------- bosses and kills
## a boss falls: extra lines for boss_defeated ("" = none)
static func on_boss(type: String) -> String:
	var out := []
	match type:
		"arbiter":
			if at_least("shards"):
				var m := take_shard("judgement")
				if m != "":
					out.append(m)
		"glaciertitan":
			var m2 := take_shard("frost")
			if m2 != "":
				out.append(m2)
			if str(st()["heart"]) == "none":
				st()["heart"] = "have"
				out.append(line("t_heart"))
		"ancientwyrm":
			if step() in ["descend", "forge", "shards", "keeper"]:
				st()["step"] = "slain"
			out.append(line("t_slain"))
	Game.save_game()
	return "\n".join(out)

## a foe falls anywhere: Hom's wolf count; returns a toast ("" = none)
static func on_kill(type: String) -> String:
	if type != "frostwolf":
		return ""
	var h := hesk()
	if h["wolves_st"] != "active":
		return ""
	h["wolves"] = min(WOLVES_NEED, int(h["wolves"]) + 1)
	if int(h["wolves"]) >= WOLVES_NEED:
		h["wolves_st"] = "ready"
		return line("t_wolves_done")
	return fmt("t_wolf", [int(h["wolves"]), WOLVES_NEED])

## a journal page picked up (n = 1..3): the toast; the page's text is read with page_lines()
static func take_page(_n: int) -> String:
	var h := hesk()
	h["pages"] = min(PAGES, int(h["pages"]) + 1)
	if h["pages_st"] != "done" and int(h["pages"]) >= PAGES:
		h["pages_st"] = "ready"
		return line("t_pages_done")
	return fmt("t_page", [int(h["pages"])])

static func page_lines(n: int) -> Array:
	return [line("page%d" % n)]

# ---------------------------------------------------------------- Hom
static func hesk_lines() -> Array:
	var h := hesk()
	if not bool(h["met"]):
		return [line("h1"), line("h2"), line("h3"), line("h4"), line("h5")]
	var ls := []
	if h["wolves_st"] == "ready":
		ls.append(line("h_w1"))
	if h["pages_st"] == "ready":
		ls.append_array([line("h_p1"), line("h_p2"), line("h_p3")])
	if ls.is_empty():
		if h["wolves_st"] == "done" and h["pages_st"] == "done":
			return [line("h_done")]
		return [fmt("h_prog", [int(h["wolves"]), int(h["pages"])])]
	return ls

## after Hom's lines: rewards paid; returns the toasts
static func hesk_done() -> Array:
	var h := hesk()
	var out := []
	if not bool(h["met"]):
		h["met"] = true
		h["wolves_st"] = "active"
		h["pages_st"] = "active" if int(h["pages"]) < PAGES else "ready"
		if h["pages_st"] == "ready":
			return out          # the pages were all found before meeting him: he reads them next time
	if h["wolves_st"] == "ready":
		h["wolves_st"] = "done"
		out.append(_pay(250, "rare"))
	if h["pages_st"] == "ready":
		h["pages_st"] = "done"
		out.append(_pay(300, "epic"))
	Game.save_game()
	Game.stats_changed.emit()
	return out

static func _pay(gold: int, rarity: String) -> String:
	var g := int(round(gold * Game.gold_mul()))
	Game.state["gold"] = int(Game.state.get("gold", 0)) + g
	Game.Gear.grant(Game.Gear.roll(rarity))
	return fmt("t_vault_gold", [g])

# ---------------------------------------------------------------- Jamshid and the frost-heart
static func brann_lines() -> Array:
	if str(st()["heart"]) != "have":
		return []
	if int(Game.state.get("weapon", 0)) >= 6 and int(Game.state.get("armor", 0)) >= 5:
		return [line("b_more")]
	return [line("b1"), line("b2"), line("b3")]

static func brann_done() -> String:
	if str(st()["heart"]) != "have":
		return ""
	st()["heart"] = "forged"
	var better := false
	if int(Game.state.get("weapon", 0)) < 6:
		Game.state["weapon"] = 6
		better = true
	if int(Game.state.get("armor", 0)) < 5:
		Game.state["armor"] = 5
		better = true
	Game.save_game()
	Game.stats_changed.emit()
	return line("t_forged") if better else ""

# ---------------------------------------------------------------- the vault (scripts/vault.gd keeps the pieces)
static func vault_breakable() -> bool:
	return east_open()

## the vault's treasure, once: the Shard of Memory, gold, a greater potion, an epic accessory. Returns the toasts.
static func open_vault() -> Array:
	var s := st()
	if bool(s["vault_open"]):
		return []
	s["vault_open"] = true
	var out := []
	var g := int(round(150.0 * Game.gold_mul()))
	Game.state["gold"] = int(Game.state.get("gold", 0)) + g
	Game.state["greater"] = int(Game.state.get("greater", 0)) + 1
	Game.Gear.grant(Game.Gear.roll("epic"))
	out.append(fmt("t_vault_gold", [g]) + Game.t(" · +1 Greater Potion", "، +۱ معجون بزرگ"))
	var m := take_shard("memory")
	if m != "":
		out.append(m)
	Game.save_game()
	return out

# ---------------------------------------------------------------- the quest log (Hero page): [icon, title, status, done]
static func log_lines() -> Array:
	var out := []
	if open() or step() != "":
		var stt := ""
		match step():
			"":
				stt = Game.t("speak with Zal", "با زال صحبت کن")
			"keeper":
				stt = Game.t("find Sorush", "سروش را پیدا کن")
			"shards":
				stt = Game.t("shards %d/3" % shards_have(), "تکه‌ها %s/۳" % Game.num(shards_have()))
			"forge":
				stt = Game.t("return to Sorush", "نزدِ سروش برگرد")
			"descend":
				stt = Game.t("the Wyrm's Hollow", "مغاکِ اژدها")
			"slain":
				stt = Game.t("return to Zal", "نزدِ زال برگرد")
			"done":
				stt = Game.t("done", "انجام شد")
		out.append(["scroll-text" if step() != "done" else "check", line("title"), stt, step() == "done"])
	match str(st()["heart"]):
		"have":
			out.append(["scroll-text", line("q_heart"), Game.t("bring the heart to Jamshid", "قلب را نزدِ جمشید ببر"), false])
		"forged":
			out.append(["check", line("q_heart"), Game.t("done", "انجام شد"), true])
	var h := hesk()
	if bool(h["met"]):
		var w_done: bool = h["wolves_st"] == "done"
		out.append(["check" if w_done else "target", line("q_wolves"), Game.t("done", "انجام شد") if w_done else ("%s/%s" % [Game.num(int(h["wolves"])), Game.num(WOLVES_NEED)]), w_done])
		var p_done: bool = h["pages_st"] == "done"
		out.append(["check" if p_done else "scroll-text", line("q_pages"), Game.t("done", "انجام شد") if p_done else ("%s/%s" % [Game.num(int(h["pages"])), Game.num(PAGES)]), p_done])
	return out
