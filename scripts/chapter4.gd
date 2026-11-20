extends RefCounted
## Chapter IV prototype: The Silent Wind.
## This vertical slice is intentionally limited to one pass, one rescue and a return to Zal.

const ELDER_ID := "elder"
const SCOUT_ID := "alborz_scout"
const GUARDS := ["serpentguard", "serpentarcher"]
static var _elder_told := ""

const L := {
	"title": ["The Silent Wind", "بادِ خاموش"],
	"intro1": ["Zal — the chains beneath Damavand hold, but the Alborz pass has fallen strangely silent.", "زال — زنجیرهای زیر دماوند پابرجا هستند، اما گذرگاه البرز به شکلی غریب خاموش شده است."],
	"intro2": ["A scout went ahead to find the missing wind. He has not returned. The old cloth markers still point east; follow them, read the gusts, and bring him back alive.", "دیده‌بانی برای یافتن بادِ گمشده پیش‌تر رفت و بازنگشته است. نشانه‌های پارچه‌ای هنوز به شرق اشاره می‌کنند؛ تندبادها را بخوان و او را زنده بازگردان."],
	"intro3": ["Do not fight the mountain. Watch the warning, let the gust pass, and use the stone shelters.", "با کوه نجنگ. هشدار را ببین، بگذار تندباد بگذرد و از پناهگاه‌های سنگی استفاده کن."],
	"o_start": ["Speak with Zal", "با زال صحبت کن"],
	"o_pass": ["Reach the Alborz pass beyond the Ashen Peaks", "از قله‌های خاکستر به گذرگاه البرز برس"],
	"o_scout": ["Clear the serpent guards and speak with the trapped scout", "پاسداران مارنشان را شکست بده و با دیده‌بان گرفتار صحبت کن"],
	"o_return": ["Return to Zal with the scout's report", "با گزارش دیده‌بان نزد زال برگرد"],
	"g_locked": ["The Alborz pass is not ready to be crossed. Zal may know why.", "گذرگاه البرز هنوز برای عبور آماده نیست. شاید زال دلیلش را بداند."],
	"g_speak": ["Zal asked you to read the wind before entering the pass.", "زال خواسته پیش از ورود به گذرگاه، باد را بخوانی."],
	"e_pass": ["The old markers still point east. Keep to the stone shelters when the cloth snaps taut.", "نشانه‌های کهن هنوز به شرق اشاره می‌کنند. وقتی پارچه‌ها کشیده شدند، به پناهگاه‌های سنگی پناه ببر."],
	"e_rescue": ["The scout is still trapped in the pass. The serpent guards have not been driven off.", "دیده‌بان هنوز در گذرگاه گرفتار است. پاسداران مارنشان عقب رانده نشده‌اند."],
	"e_return1": ["You found him. The scout says the wind was knotted around the narrowest stone throat, not stopped at its source.", "پیدایش کردی. دیده‌بان می‌گوید باد در تنگ‌ترین گلوی سنگی گره خورده بود، نه آن‌که از سرچشمه‌اش بند آمده باشد."],
	"e_return2": ["That is enough for now. We have opened a safe road into the Alborz. The deeper silence will need another journey.", "برای اکنون همین بس است. راهی امن به البرز گشوده‌ایم. خاموشیِ ژرف‌تر به سفری دیگر نیاز دارد."],
	"e_done": ["The first passage is safe. I will keep watch on the mountain.", "گذرگاه نخست امن شده است. من مراقب کوه خواهم ماند."],
	"s_guarded": ["The guards keep the pass closed. I cannot leave while they still circle the shelters.", "پاسداران راه را بسته‌اند. تا وقتی دور پناهگاه‌ها می‌چرخند نمی‌توانم از این‌جا بروم."],
	"s_free1": ["You have broken their ring. I can reach the eastern marker now.", "حلقهٔ محاصره‌شان را شکستی. حالا می‌توانم به نشانهٔ شرقی برسم."],
	"s_free2": ["I heard the gusts before I saw them. The wind is being forced through a narrow throat in the rock. The deeper pass lies beyond this first crossing.", "پیش از دیدن تندبادها صدایشان را شنیدم. باد را به زور از گلویی باریک در دل سنگ می‌گذرانند. گذرگاه ژرف‌تر پس از این گذر نخست قرار دارد."],
	"t_open": ["The Alborz pass is open. The scout is waiting beyond the wind shelters.", "گذرگاه البرز گشوده شد. دیده‌بان آن‌سوی پناهگاه‌های باد منتظر است."],
	"t_scout": ["The scout is safe. Return to Zal.", "دیده‌بان در امان است. نزد زال برگرد."],
	"t_done": ["Alborz pass secured — the first part of the Silent Wind is complete.", "گذرگاه البرز امن شد — بخش نخستِ باد خاموش به پایان رسید."],
	"t_gold": ["+%d Gold", "+%s سکه"]
}

static func line(id: String) -> String:
	var pair: Array = L.get(id, [id, id])
	return Game.t(str(pair[0]), str(pair[1]))

static func fmt(id: String, args: Array) -> String:
	var pair: Array = L.get(id, [id, id])
	if Game.lang == "fa":
		var fa_args: Array = []
		for value in args:
			fa_args.append(Game.num(value) if typeof(value) == TYPE_INT else value)
		return str(pair[1]).replace("%d", "%s") % fa_args
	return str(pair[0]) % args

static func st() -> Dictionary:
	var value: Variant = Game.state.get("c4", null)
	if typeof(value) != TYPE_DICTIONARY:
		value = {"step": "", "scout_rescued": false}
		Game.state["c4"] = value
	if not value.has("step"):
		value["step"] = ""
	if not value.has("scout_rescued"):
		value["scout_rescued"] = false
	return value

static func step() -> String:
	return str(st()["step"])

static func open() -> bool:
	return Game.Ch3.step() == "done"

static func path_open() -> bool:
	return open() and step() in ["pass", "rescue", "return", "done"]

static func set_step(value: String) -> void:
	st()["step"] = value
	Game.save_game()
	Game.stats_changed.emit()

static func on_map_entered(map_key: String) -> void:
	if map_key == "alborz" and step() == "pass":
		set_step("rescue")

static func objective() -> String:
	if not open():
		return ""
	match step():
		"":
			return line("o_start")
		"pass":
			return line("o_pass")
		"rescue":
			return line("o_scout")
		"return":
			return line("o_return")
	return ""

static func target() -> Dictionary:
	if not open():
		return {}
	var graph := Game.world_graph()
	var elder_pos: Vector2 = Game._v(graph.get("village", {}).get("npcs", {}).get("elder", [443, 334]))
	match step():
		"":
			return {"map": "village", "pos": elder_pos, "kind": "npc"}
		"pass":
			return {"map": "peaks", "pos": Vector2(990, 10), "kind": "exit"}
		"rescue":
			var scout_pos: Vector2 = Game._v(graph.get("alborz", {}).get("npcs", {}).get(SCOUT_ID, [248, 554]))
			return {"map": "alborz", "pos": scout_pos, "kind": "npc"}
		"return":
			return {"map": "village", "pos": elder_pos, "kind": "npc"}
	return {}

static func has_news(id: String) -> bool:
	if not open():
		return false
	if id == ELDER_ID:
		return step() in ["", "return"]
	if id == SCOUT_ID:
		return step() == "rescue"
	return false

static func exit_block(to: String) -> String:
	if to != "alborz":
		return ""
	if not open():
		return line("g_locked")
	if step() == "":
		return line("g_speak")
	return ""

static func elder_lines() -> Array:
	_elder_told = ""
	if not open():
		return []
	_elder_told = step()
	match step():
		"":
			return [line("intro1"), line("intro2"), line("intro3")]
		"pass":
			return [line("e_pass")]
		"rescue":
			return [line("e_rescue")]
		"return":
			return [line("e_return1"), line("e_return2")]
	return [line("e_done")]

static func elder_done() -> String:
	if not open() or _elder_told != step():
		return ""
	var spoken := _elder_told
	_elder_told = ""
	if spoken == "":
		set_step("pass")
		return line("t_open")
	if spoken == "return":
		set_step("done")
		var gold := 180
		Game.state["gold"] = int(Game.state.get("gold", 0)) + gold
		Game.save_game()
		return fmt("t_gold", [gold]) + "\n" + line("t_done")
	return ""

static func guards_cleared(world: Node) -> bool:
	if world == null or not is_instance_valid(world):
		return false
	for enemy in world.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead or enemy.world != world:
			continue
		if str(enemy.type) in GUARDS:
			return false
	return true

static func scout_lines(world: Node) -> Array:
	if step() != "rescue":
		return [line("e_done")]
	if not guards_cleared(world):
		return [line("s_guarded")]
	return [line("s_free1"), line("s_free2")]

static func scout_done(world: Node) -> String:
	if step() != "rescue" or not guards_cleared(world):
		return ""
	st()["scout_rescued"] = true
	set_step("return")
	return line("t_scout")
