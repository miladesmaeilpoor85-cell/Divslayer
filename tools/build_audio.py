#!/usr/bin/env python3
"""Build assets/audio/ from the downloaded CC0 sources (v0.17).

    python3 tools/build_audio.py --kenney DIR --innworld DIR --frostbound DIR [--q 10]

  --kenney    a checkout of the Kenney packs (kenney_rpgaudio, kenney_impactsounds, kenney_interfacesounds,
              kenney_uiaudio, kenney_musicjingles), each with its own License.txt (CC0)
  --innworld  the audio folder of github.com/Daddy-Ousen/innworld-rpg (game/assets/audio), which keeps CC0
              OpenGameArt tracks; every one used here was checked on its OpenGameArt page (see assets/audio/CREDITS.md)
  --frostbound  the audio/music folder of github.com/seskiramadhan/Frostbound (two CC0 OpenGameArt tracks, v0.19)

Files are encoded to high-quality Ogg Vorbis, loudness-matched (EBU R128, two passes), and edited only where musically intended. Source channels are preserved unless a deliberate mono treatment is specified.
Needs ffmpeg with libvorbis. The output is deterministic for the same sources and settings.
"""
import argparse, json, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")

# region -> (source file in innworld/music, title, author, OpenGameArt page, target loudness, max seconds or None)
MUSIC = {
	"title":      ("lament_warriors_soul.mp3", "Fantasy: Lament for a Warrior's Soul", "RandomMind", "https://opengameart.org/content/fantasy-lament-for-a-warriors-soul", -19, 130),
	"village":    ("market_day.mp3", "Medieval: Market Day (loop)", "RandomMind", "https://opengameart.org/content/medieval-market-day", -19, None),
	"forest":     ("field_of_dreams.mp3", "The Field Of Dreams", "pauliuw", "https://opengameart.org/content/the-field-of-dreams", -19, None),
	"dungeon":    ("forgotten_tombs.mp3", "Forgoten tomb ambience", "kindland", "https://opengameart.org/content/forgoten-tomb-ambience", -23, 120),
	"peaks":      ("doom_in_the_morning.mp3", "Doom in the Morning", "VishwaJai", "https://opengameart.org/content/doom-in-the-morning", -19, None),
	"shadowfen":  ("rising_moon.mp3", "Fantasy: Rising Moon", "RandomMind", "https://opengameart.org/content/fantasy-rising-moon", -20, 150),
	"sanctum":    ("cold_hands.ogg", "Cold Hands", "SkyleTheFrench", "https://opengameart.org/content/cold-hands", -20, None),
	"emberforge": ("fall_of_nightmares.ogg", "Fall of Nightmares [Epic, Orchestral]", "nene", "https://opengameart.org/content/fall-of-nightmares-epic-orchestral", -18, None),
	"camp":       ("bards_tale.mp3", "Medieval: The Bard's Tale", "RandomMind", "https://opengameart.org/content/medieval-the-bards-tale", -20, 125),
	"trial":      ("medieval_battle.mp3", "Medieval: Battle", "RandomMind", "https://opengameart.org/content/medieval-battle", -18, None),
	"boss":       ("battle_theme_a.mp3", "Battle Theme A", "cynicmusic", "https://opengameart.org/content/battle-theme-a", -17, None),
	"shrine":     ("heavenly_loop.ogg", "Heavenly Loop", "isaiah658", "https://opengameart.org/content/heavenly-loop", -22, None),
	# v0.19, chapter 2 ("frostbound:" = from --frostbound)
	"frostvale":  ("frostbound:explore.mp3", "Medieval: Exploration", "RandomMind", "https://opengameart.org/content/medieval-exploration", -19, 165),
	"wyrmhollow": ("snowfall.ogg", "Snowfall (looped version)", "Kistol", "https://opengameart.org/content/snowfall", -21, None),
	"boss_ancientwyrm": ("frostbound:boss.mp3", "Boss Battle Music (Epic Boss Battle)", "SubspaceAudio (Juhani Junkala)", "https://opengameart.org/content/boss-battle-music", -17, None),
}

# loop name -> (source in innworld/ambience, title, author, page, loudness, mono-by-design)
AMBIENCE = {
	"crickets": ("amb_crickets.ogg", "Crickets Ambient Noise - loopable", "Wolfgang_ (Ted Kerr)", "https://opengameart.org/content/crickets-ambient-noise-loopable", -28, False),
	"wind":     ("amb_wind.ogg", "wind whoosh loop", "SketchMan3", "https://opengameart.org/content/wind-whoosh-loop", -26, False),
	"birds":    ("amb_birds.ogg", "Ambient Bird Sounds (cut to loop)", "isaiah658", "https://opengameart.org/content/ambient-bird-sounds", -30, False),
	"fire":     ("amb_fire.ogg", "Fireplace Sound loop (cut to loop)", "PagDev", "https://opengameart.org/content/fireplace-sound-loop", -27, False),
	"cave":     ("amb_cave.ogg", "Loopable Dungeon Ambience", "JaggedStone", "https://opengameart.org/content/loopable-dungeon-ambience", -27, False),
	"water":    ("amb_water.ogg", "loop_water_02 (40 CC0 water / splash / slime SFX)", "rubberduck", "https://opengameart.org/content/40-cc0-water-splash-slime-sfx", -29, False),
}

# Preserve the original channel layout. Mono is allowed only when it is an intentional sound-design choice.
MONO_MUSIC = set()
# every ambience loop is re-folded so its end runs into its start without a click: name -> (seconds kept, crossfade).
# The cave loop is also shortened (94 s -> 48 s); the others keep their length and get a 0.3 s crossfade.
AMB_FOLD = {"cave": (48.0, 3.0)}

KENNEY = {
	"kenney_rpgaudio": ("RPG Audio", "https://kenney.nl/assets/rpg-audio"),
	"kenney_impactsounds": ("Impact Sounds", "https://kenney.nl/assets/impact-sounds"),
	"kenney_interfacesounds": ("Interface Sounds", "https://kenney.nl/assets/interface-sounds"),
	"kenney_uiaudio": ("UI Audio", "https://kenney.nl/assets/ui-audio"),
	"kenney_musicjingles": ("Music Jingles", "https://kenney.nl/assets/music-jingles"),
}
OGA_SFX = {
	"swish": ("Swishes Sound Pack", "artisticdude", "https://opengameart.org/content/swishes-sound-pack"),
	"creature": ("80 CC0 creature SFX", "rubberduck", "https://opengameart.org/content/80-cc0-creature-sfx"),
	"splash": ("40 CC0 water / splash / slime SFX", "rubberduck", "https://opengameart.org/content/40-cc0-water-splash-slime-sfx"),
}

# sound name -> list of (source kind, path relative to its pack), every entry one variation
def K(pack, *names):
	return [("kenney", pack + "/" + n) for n in names]
def I(*names):
	return [("innworld", "sfx/" + n) for n in names]
SFX = {
	"swing":   I("swish-1.wav", "swish-2.wav", "swish-3.wav", "swish-4.wav"),
	"swing2":  I("swish-5.wav", "swish-6.wav", "swish-7.wav"),
	"heavy":   I("swish-8.wav", "swish-9.wav"),
	"hit":     K("kenney_impactsounds/Audio", *["impactPunch_medium_%03d.ogg" % i for i in range(5)]),
	"crit":    K("kenney_rpgaudio/Audio", "knifeSlice.ogg", "knifeSlice2.ogg"),
	"hurt":    K("kenney_impactsounds/Audio", *["impactPunch_heavy_%03d.ogg" % i for i in range(5)]),
	"clank":   K("kenney_impactsounds/Audio", *["impactPlate_light_%03d.ogg" % i for i in range(5)]),
	"trap":    K("kenney_impactsounds/Audio", *["impactWood_heavy_%03d.ogg" % i for i in range(3)]),
	"dodge":   K("kenney_rpgaudio/Audio", "cloth1.ogg", "cloth2.ogg", "cloth3.ogg", "cloth4.ogg"),
	"coin":    K("kenney_rpgaudio/Audio", "handleCoins.ogg", "handleCoins2.ogg"),
	"door":    K("kenney_rpgaudio/Audio", "doorOpen_1.ogg", "doorOpen_2.ogg"),
	"talk":    K("kenney_rpgaudio/Audio", "bookFlip1.ogg", "bookFlip2.ogg", "bookFlip3.ogg"),
	"book":    K("kenney_rpgaudio/Audio", "bookOpen.ogg"),
	"equip":   K("kenney_rpgaudio/Audio", "clothBelt.ogg", "clothBelt2.ogg", "beltHandle1.ogg"),
	"latch":   K("kenney_rpgaudio/Audio", "metalLatch.ogg"),
	"chest":   K("kenney_rpgaudio/Audio", "creak1.ogg", "creak2.ogg"),
	"ui":      K("kenney_uiaudio/Audio", "click1.ogg", "click2.ogg", "click3.ogg"),
	"error":   K("kenney_interfacesounds/Audio", "error_004.ogg", "error_006.ogg"),
	"potion":  K("kenney_interfacesounds/Audio", "glass_002.ogg", "glass_004.ogg"),
	"quest":   K("kenney_musicjingles/Audio/Pizzicato jingles", "jingles_PIZZI10.ogg"),
	"levelup": K("kenney_musicjingles/Audio/Pizzicato jingles", "jingles_PIZZI02.ogg"),
	"victory": K("kenney_musicjingles/Audio/Pizzicato jingles", "jingles_PIZZI15.ogg"),
	"defeat":  K("kenney_musicjingles/Audio/Pizzicato jingles", "jingles_PIZZI07.ogg"),
	"found":   K("kenney_musicjingles/Audio/Pizzicato jingles", "jingles_PIZZI16.ogg"),
	"achieve": K("kenney_musicjingles/Audio/Steel jingles", "jingles_STEEL02.ogg"),     # (v0.20) an achievement: a rising steel-drum run
	"roar":    I("creature_roar_01.ogg", "creature_roar_02.ogg", "creature_roar_03.ogg"),
	"growl":   I("creature_monster_01.ogg", "creature_monster_02.ogg", "creature_monster_03.ogg", "creature_grunt_01.ogg", "creature_grunt_02.ogg"),
	"die":     I("creature_hurt_01.ogg", "creature_hurt_02.ogg", "creature_hurt_03.ogg", "creature_hurt_04.ogg"),
	"slime":   I("creature_burble_01.ogg", "creature_burble_02.ogg", "water_splash_01.ogg"),
	"bug":     I("creature_bug_01.ogg", "creature_bug_02.ogg", "creature_bug_03.ogg"),
	"step_grass":    K("kenney_impactsounds/Audio", *["footstep_grass_%03d.ogg" % i for i in range(5)]),
	"step_stone":    K("kenney_impactsounds/Audio", *["footstep_concrete_%03d.ogg" % i for i in range(5)]),
	"step_snow":     K("kenney_impactsounds/Audio", *["footstep_snow_%03d.ogg" % i for i in range(5)]),
}

def run(cmd):
	r = subprocess.run(cmd, capture_output=True, text=True)
	if r.returncode != 0:
		sys.exit("ffmpeg failed: " + " ".join(cmd) + "\n" + r.stderr[-2000:])
	return r

def measure(src, pre=""):
	"""first loudnorm pass: returns the measured values"""
	af = (pre + "," if pre else "") + "loudnorm=print_format=json"
	r = run(["ffmpeg", "-hide_banner", "-nostats", "-i", src, "-af", af, "-f", "null", "-"])
	m = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr, re.S)
	return json.loads(m.group(0))

def duration(src):
	r = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", src])
	return float(r.stdout.strip())

def encode(src, dst, lufs, q, mono=False, rate=44100, trim=None, fade_in=0.0, fade_out=0.0, tp=-1.5):
	pre = []
	if mono:
		# downmix first, inside the chain, so the loudness pass and the limiter see the final signal
		# (ffmpeg's own -ac 1 mixes at -3 dB per side: in-phase material comes out +3 dB hotter and clipped)
		pre.append("pan=mono|c0=0.5*c0+0.5*c1")
	if trim:
		pre.append("atrim=0:%g" % trim)
	if fade_in > 0:
		pre.append("afade=t=in:st=0:d=%g" % fade_in)
	if fade_out > 0:
		end = trim if trim else duration(src)
		pre.append("afade=t=out:st=%g:d=%g" % (max(0.0, end - fade_out), fade_out))
	pre_s = ",".join(pre)
	m = measure(src, pre_s)
	ln = ("loudnorm=I=%g:TP=%g:LRA=11:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true"
		% (lufs, tp, m["input_i"], m["input_tp"], m["input_lra"], m["input_thresh"], m["target_offset"]))
	# a gentle limiter after the gain: a quiet track with sharp peaks (the tomb drone) can otherwise overshoot 0 dBFS
	lim = ",alimiter=limit=%.3f:attack=5:release=60:level=false:latency=true" % (10 ** ((tp - 0.5) / 20.0))
	af = (pre_s + "," if pre_s else "") + ln + lim + ",aresample=%d" % rate
	cmd = ["ffmpeg", "-hide_banner", "-y", "-i", src, "-af", af, "-ac", "1" if mono else "2", "-c:a", "libvorbis", "-q:a", str(q), "-map_metadata", "-1", dst]
	run(cmd)

def fold_loop(src, keep, dst, x=3.0):
	"""a shorter seamless loop: keep the first keep+x seconds and mix the last x seconds (fading out) over the first x
	(fading in, equal power). Playing [0, keep) on repeat then joins without a seam."""
	import wave, struct
	tmp = dst + ".raw.wav"
	run(["ffmpeg", "-hide_banner", "-y", "-i", src, "-t", "%g" % (keep + x), "-ac", "2", "-ar", "48000", "-c:a", "pcm_s24le", tmp])
	with wave.open(tmp) as w:
		n = w.getnframes()
		raw = w.readframes(n)
	os.remove(tmp)
	import array, math
	a = array.array("h", raw)
	xs = int(x * 48000)
	keep_n = n - xs
	out = a[: keep_n * 2]
	for i in range(xs):
		k = i / xs
		fi, fo = math.sin(k * math.pi / 2), math.cos(k * math.pi / 2)
		for c in range(2):
			v = a[i * 2 + c] * fi + a[(keep_n + i) * 2 + c] * fo
			out[i * 2 + c] = max(-32768, min(32767, int(v)))
	with wave.open(dst, "wb") as w:
		w.setnchannels(2); w.setsampwidth(3); w.setframerate(48000)
		w.writeframes(out.tobytes())
	return dst

def trim_silence_encode(src, dst, q=10):
	"""a one-shot sound: mono, leading/trailing silence cut, peak at -1 dBFS"""
	r = run(["ffmpeg", "-hide_banner", "-nostats", "-i", src, "-af", "volumedetect", "-f", "null", "-"])
	mx = float(re.search(r"max_volume: (-?[\d.]+) dB", r.stderr).group(1))
	gain = -1.0 - mx
	af = "silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.005,areverse,silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.02,areverse,volume=%.2fdB,aresample=48000" % gain
	run(["ffmpeg", "-hide_banner", "-y", "-i", src, "-af", af, "-c:a", "libvorbis", "-q:a", str(q), "-map_metadata", "-1", dst])

def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--kenney", required=True)
	ap.add_argument("--innworld", required=True)
	ap.add_argument("--frostbound", required=True)
	ap.add_argument("--q", type=float, default=10.0, help="Vorbis quality for music, 0..10; default 10 preserves maximum encoder quality")
	ap.add_argument("--rate", type=int, default=48000, help="music sample rate; quality-first default is 48 kHz (no size-driven downsampling)")
	a = ap.parse_args()
	for sub in ("music", "amb", "sfx"):
		d = os.path.join(OUT, sub)
		if os.path.isdir(d):
			shutil.rmtree(d)
		os.makedirs(d)
	credits = {"music": [], "ambience": [], "sfx": []}
	for key, (f, title, author, url, lufs, cap) in MUSIC.items():
		src = os.path.join(a.frostbound, f.split(":", 1)[1]) if f.startswith("frostbound:") else os.path.join(a.innworld, "music", f)
		dur = duration(src)
		trim = cap if cap and dur > cap else None
		encode(src, os.path.join(OUT, "music", key + ".ogg"), lufs, max(0.0, a.q), mono=key in MONO_MUSIC, rate=a.rate, trim=trim, fade_out=(4.0 if trim else 0.0))
		credits["music"].append({"use": key, "title": title, "author": author, "url": url, "license": "CC0 1.0", "edit": "trimmed with a fade-out" if trim else "re-encoded"})
	for key, (f, title, author, url, lufs, mono) in AMBIENCE.items():
		src = os.path.join(a.innworld, "ambience", f)
		keep, xf = AMB_FOLD.get(key, (duration(src) - 0.3, 0.3))
		folded = fold_loop(src, keep, os.path.join(OUT, "amb", key + "_fold.wav"), xf)
		encode(folded, os.path.join(OUT, "amb", key + ".ogg"), lufs, 10, mono=mono, rate=48000, tp=-3.0)
		os.remove(folded)
		credits["ambience"].append({"use": key, "title": title, "author": author, "url": url, "license": "CC0 1.0"})
	used_packs = set()
	used_oga = set()
	table = {}
	for name, srcs in SFX.items():
		table[name] = []
		for i, (kind, rel) in enumerate(srcs):
			src = os.path.join(a.kenney if kind == "kenney" else a.innworld, rel)
			if not os.path.isfile(src):
				sys.exit("missing source: " + src)
			out = "%s_%d.ogg" % (name, i)
			trim_silence_encode(src, os.path.join(OUT, "sfx", out))
			table[name].append(out)
			if kind == "kenney":
				used_packs.add(rel.split("/")[0])
			else:
				base = os.path.basename(rel)
				used_oga.add("swish" if base.startswith("swish") else ("splash" if base.startswith("water") else "creature"))
	for p in sorted(used_packs):
		credits["sfx"].append({"title": KENNEY[p][0], "author": "Kenney (www.kenney.nl)", "url": KENNEY[p][1], "license": "CC0 1.0"})
	for k in sorted(used_oga):
		t, au, url = OGA_SFX[k]
		credits["sfx"].append({"title": t, "author": au, "url": url, "license": "CC0 1.0"})
	# (no index file: scripts/sfx.gd finds the variations by name, <sound>_0.ogg, <sound>_1.ogg ...)
	with open(os.path.join(ROOT, "data", "audio_credits.json"), "w", encoding="utf-8") as fh:
		json.dump(credits, fh, indent=1, ensure_ascii=False)
	# the human-readable credits next to the files
	lines = ["# Audio credits", "", "Every sound and track here is **CC0 1.0** (public domain): free for commercial use, no credit required.",
		"Credit is given anyway, with thanks. All files were re-encoded to Ogg Vorbis and loudness-matched by tools/build_audio.py.", ""]
	for sec, head in (("music", "Music"), ("ambience", "Ambience loops"), ("sfx", "Sound effects")):
		lines += ["## " + head, ""]
		for c in credits[sec]:
			use = (" — used for: " + c["use"]) if "use" in c else ""
			edit = (" (" + c["edit"] + ")") if c.get("edit") and c["edit"] != "re-encoded" else ""
			lines.append("- \"%s\" by %s%s. %s. %s%s" % (c["title"], c["author"], edit, c["license"], c["url"], use))
		lines.append("")
	lines += ["Kenney packs ship their own License.txt (CC0); copies are in assets/audio/licenses/.", ""]
	with open(os.path.join(OUT, "CREDITS.md"), "w", encoding="utf-8") as fh:
		fh.write("\n".join(lines))
	lic = os.path.join(OUT, "licenses")
	os.makedirs(lic, exist_ok=True)
	for p in sorted(used_packs):
		for fn in os.listdir(os.path.join(a.kenney, p)):
			if fn.lower().startswith("license"):
				shutil.copy(os.path.join(a.kenney, p, fn), os.path.join(lic, p + "_License.txt"))
	total = 0
	for dp, _, fs in os.walk(OUT):
		total += sum(os.path.getsize(os.path.join(dp, f)) for f in fs)
	print("audio total %.2f MB" % (total / 1e6))

if __name__ == "__main__":
	main()
