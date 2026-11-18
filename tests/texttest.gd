extends Node
## v0.24 checks on the text itself (the critic's table): no name the game has left behind (Elder Godarz, a hero with a
## name of his own, the Judge of the Sanctum…), one style for the Persian (the ezafe after a silent he is "هٔ"; no "·"
## between items — it reads as the Persian zero; no "باس"), and Zal speaking to the Ember-bearer in every state of the tale.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/texttest.gd

var results := {}
var fails: Array = []

const BANNED := ["Godarz", "گودرز", "Jamshid the Exile", "جمشیدِ تبعیدی", "ریش‌سفید", "Elder Godarz", "کالبدت", "آزمونِ خاکستر", "حماسه‌ی خاکستر", "قاضیِ معبد",
	"Judge of", "نامت به‌تنهایی", "Your name alone", "Holy Smite", "HOLY SMITE", "Torvin", "بهزاد", "سردابه", "سیاه‌خانه",
	"ضربهٔ بحرانی", "پولت را پس", "Even Rostam was not", "Champion of Zabol", "قهرمانِ زابل", "شوالیه", "فاز آخر", "فاز دوم",
	"دینِ تبعیدی", "Exile's Debt", "تیرِ کمین", "Ambush Arrow", "Warden of the Sunken", "پاسدار سردابِ", "بخوانش تا"]

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

func files(dir: String, ext: Array, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if ext.has(f.get_extension()):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		files(dir.path_join(sub), ext, out)

## the double-quoted string literals of a file, comments left out
func literals(path: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var code: String = line
		if path.ends_with(".gd"):
			var hash := _comment_at(line)
			if hash >= 0:
				code = line.substr(0, hash)
		for m in re.search_all(code):
			out.append(m.get_string(1))
	return out

## where a "#" comment starts outside a string, or -1
func _comment_at(line: String) -> int:
	var inside := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\\" and inside:
			i += 2
			continue
		if c == "\"":
			inside = not inside
		elif c == "#" and not inside:
			return i
		i += 1
	return -1

func is_fa(s: String) -> bool:
	for i in s.length():
		var u := s.unicode_at(i)
		if u >= 0x0600 and u <= 0x06FF:
			return true
	return false

func run(_m: Node) -> void:
	await get_tree().process_frame
	var all := []
	files("res://scripts", ["gd"], all)
	files("res://data", ["json"], all)
	var banned := []
	var ezafe := []
	var dots := []
	var boss := []
	var re_ez := RegEx.new()
	re_ez.compile("ه‌ی(?![؀-ۿ])")
	var re_boss := RegEx.new()
	re_boss.compile("(?<![؀-ۿ‌])باس(?![؀-ۿ]|‌(?!ها))")
	for f in all:
		if str(f).ends_with("world_graph.json"):
			continue
		for s in literals(f):
			for b in BANNED:
				if str(s).contains(b):
					banned.append([f.get_file(), b])
			if is_fa(s):
				if re_ez.search(s):
					ezafe.append([f.get_file(), s.left(40)])
				if s.contains("·"):
					dots.append([f.get_file(), s.left(40)])
				if re_boss.search(s):
					boss.append([f.get_file(), s.left(40)])
	check("scanned_the_text", all.size() > 60, all.size())
	check("no_names_left_behind", banned.is_empty(), banned.slice(0, 8))
	check("one_ezafe", ezafe.is_empty(), ezafe.slice(0, 6))
	check("no_dot_in_persian", dots.is_empty(), dots.slice(0, 6))
	check("no_boss_loanword", boss.is_empty(), boss.slice(0, 6))
	Game.lang = "fa"
	check("separator", Game.sep() == "، " and Game.sep(true) == "، ")
	Game.lang = "en"
	check("separator_en", Game.sep() == " · " and Game.sep(true) == "  ·  ")
	# Zal, through the tale: always the Ember-bearer, never "Champion"
	Game.lang = "fa"
	Game.new_game("mage")
	var said := []
	var states := [["not_started", "", ""], ["active", "", ""], ["complete", "", ""], ["done", "not_started", ""], ["done", "complete", ""],
		["done", "done", "not_started"], ["done", "done", "complete"]]
	for st in states:
		Game.set_q(1, st[0])
		if st[1] != "":
			Game.set_q(2, st[1])
		if st[2] != "":
			Game.set_q(3, st[2])
		said.append_array(Game.elder_lines())
	var joined := " ".join(said)
	check("zal_never_says_champion", not joined.contains("قهرمان") and joined.contains("اخگردار") and not joined.contains("رستم هم در سنِ تو"), said.size())
	check("zal_lines_are_persian", said.all(func(x): return is_fa(str(x))))
	Game.lang = "en"
	Game.new_game("mage")
	var en_said: Array = Game.elder_lines()
	check("zal_lines_english", str(en_said[0]).begins_with("Welcome to Zabol, ember-bearer"))
	Game.lang = "fa"

	# (v0.33) every foe has a Persian name (the four Ember Forge foes showed in English)
	var old_lang: String = Game.lang
	Game.lang = "fa"
	var unnamed := []
	for t in Game.table("ENEMY_TYPES"):
		var n: String = Game.enemy_name(t)
		if n.to_lower() == str(Game.enemy_def(t).get("name", t)).to_lower() or n.to_lower() == str(t).to_lower():
			unnamed.append(t)
	Game.lang = old_lang
	check("every_foe_named_in_persian", unnamed.is_empty(), unnamed)
	print("TEXTTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()
