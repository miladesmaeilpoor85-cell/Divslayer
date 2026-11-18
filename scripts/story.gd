extends RefCounted
## Jamshid the Exile (v0.13): the lines of the questline. The titles and toasts come from the HTML game, the dialogue is new.

const L := {
	"core_got": ["Warden Core recovered — bring it to Jamshid.", "هستهٔ نگهبان به دست آمد — به جمشید برسان."],
	"ign_out": ["Puladvand is extinguished. Return to Jamshid.", "پولادوند خاموش شد. نزد جمشید برگرد."],
	"key_got": ["Kindling Key received — the Peaks door is open.", "کلیدِ افروزنده را گرفتی — درِ قله‌ها باز شد."],
	"reward1": ["+350 Gold · weapon and armour refined", "+۳۵۰ سکه، سلاح و زره تقویت شد"],
	"reward2": ["Jamshid's masterwork: +2/+2 forge, 3 talent points", "شاهکار جمشید: +۲/+۲ آهنگری، ۳ امتیاز استعداد"],
	"title": ["The Shade of Jamshid", "روانِ جمشید"],
	"o_core": ["Return the Warden Core to Jamshid.", "هستهٔ نگهبان را به جمشید برگردان."],
	"o_anvil": ["Slay Pulad of Ghandi in the Forge.", "پولادِ غندی را در کوره بکش."],
	"o_anvil_back": ["Return to Jamshid for your reward.", "برای پاداش نزد جمشید برگرد."],
	"o_ign": ["Extinguish Puladvand, the First Flame.", "پولادوند، نخستین شعله را خاموش کن."],
	"d_core1": ["The Warden Core... still warm. You carry more heart than sense, ember-bearer.", "هستهٔ نگهبان... هنوز گرم است. دلت از خِرَدت بزرگ‌تر است، اخگردار."],
	"d_core2": ["By the kingly farr I softened iron and made helm and mail of it, before the farr left me. This core fed the Warden that bars my Forge.", "به فرّ کیانی آهن را نرم کردم و از آن خود و زره ساختم، پیش از آن‌که فرّه از من بگسلد. این هسته به نگهبانی جان می‌داد که درِ کوره‌ام را بسته است."],
	"d_core3": ["Take the Kindling Key. The sealed door in the Ashen Peaks answers to it. Beyond lies the Emberforge.", "کلیدِ افروزنده را بگیر. درِ مهرشدهٔ قله‌های خاکستر به آن جواب می‌دهد. آن‌سوی در، آهنگرخانهٔ اخگر است."],
	"d_core4": ["Slay Pulad of Ghandi, and come back to me.", "پولادِ غندی را بکش و نزدِ من برگرد."],
	"d_anvil": ["The door is open and the Warden still stands. Go, ember-bearer.", "در باز است و نگهبان هنوز ایستاده. برو، ای اخگردار."],
	"d_ab1": ["Pulad of Ghandi has fallen? Then the Forge remembers me.", "پولادِ غندی افتاد؟ پس کوره هنوز مرا به یاد دارد."],
	"d_ab2": ["Here, gold from the hoard I hid before my fall. And the fire has remembered my craft: your blade and armour are tempered anew.", "این هم زر از گنجی که پیش از افتادنم پنهان کردم. آتش هم هنرم را به یاد آورد: تیغ و زره‌ات از نو آب‌دیده شد."],
	"d_ab3": ["One flame remains: Puladvand, the First Flame. Put it out, and the mountain will sleep.", "یک شعله مانده: پولادوند، نخستین شعله. خاموشش کن تا کوه بخوابد."],
	"d_ign": ["Puladvand still burns beneath the mountain. Do not go in without your best steel.", "پولادوند هنوز زیر کوه می‌سوزد. بدون بهترین فولادت وارد نشو."],
	"d_ib1": ["The mountain is quiet. A shade feels such things — Puladvand is out.", "کوه ساکت است. روان این چیزها را حس می‌کند — پولادوند خاموش شد."],
	"d_ib2": ["Hold out your arms. This is my masterwork — the last thing these hands of smoke will forge.", "دست‌هایت را جلو بیاور. این شاهکارِ من است — واپسین چیزی که این دست‌های دودین می‌سازند."],
	"d_ib3": ["Take what I have learned of fire as well. It will serve your talents.", "آنچه از آتش آموخته‌ام را هم بگیر. به استعدادهایت کمک می‌کند."],
	"d_done": ["The First Flame sleeps, and my bond lies lighter. Keep the ember, ember-bearer — I could not.", "نخستین شعله خفت و بندِ من سبک شد. اخگر را نگه دار، اخگردار — من نتوانستم."],
	"sealed": ["A Kindling lock seals the door.\n(The Shade of Jamshid may know how to open it)", "قفلی افروزنده در را بسته است.\n(شاید روانِ جمشید بداند چطور بازش کند)"],
}

static func line(id: String) -> String:
	var p: Array = L.get(id, [id, id])
	return Game.t(str(p[0]), str(p[1]))
