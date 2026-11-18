# Ember & Iron 0.26.1 — publishing report

Publisher & marketing lead, 12 Nov 2026. Read-only on the game; nothing in the project was changed.

## 0. Read this first: what I could and could not verify

- **Build facts** come from `export_presets.cfg`, `project.godot`, `signing/`, `icon.png`, `CHANGELOG.md`, the privacy draft, the v0.26 playtest summary and critic report, and 8 screenshots I looked at. These are solid.
- **Store requirements are mostly NOT confirmed.** The official developer documentation of both stores refused automated reading (their `robots` rules block it): every page under `developers.cafebazaar.ir`, the Bazaar news blog, and the Myket publishing guide and pricing page. I did not work around that block. The only official page I could read in full is Myket's **Content Publishing Policy**. For two revenue-share facts I have only the **headline** of an article, not its text.
- So the table below gives the official URL where each rule lives, and says "not confirmed" wherever I could not read the number. **No number in this report is a guess.** Someone must open those pages in a normal browser (10 minutes of work) and fill the gaps; the developer panel itself also shows most limits when you start a listing.
- No build exists in the project (`build/` is absent), so APK size, min SDK and target SDK of the real package are unmeasured.

## a. Store requirements

"Ours" = what the project files say today.

| Requirement | Cafe Bazaar | Myket | Source | Does our build meet it? |
|---|---|---|---|---|
| Developer account for an individual (identity, bank details, fee) | Not confirmed. Steps are on the "step by step" page. | Not confirmed. Signup is in the developer panel. | Bazaar: https://developers.cafebazaar.ir/fa/guidelines/developers-panel/app-release · Myket: https://developer.myket.ir/ | **Unknown / not done.** Only Milad can do this (his own identity and bank account). |
| Package format (APK / AAB) | Not confirmed. Bazaar documents multi-package releases and OBB expansion files, which implies APK upload. | Not confirmed. | https://developers.cafebazaar.ir/fa/guidelines/feature/device-specification · https://developers.cafebazaar.ir/fa/guidelines/feature/expansion-files | **Likely yes.** Preset exports an APK (`gradle_build/export_format=0`, Gradle build off). If either store demands AAB, the preset must switch to a Gradle build. |
| Package size limit | Not confirmed (the OBB page exists because a limit exists). | Not confirmed. | same as above | **Unknown.** Project is ~59 MB on disk including tests and tools; the exported APK with two ABIs has not been built or measured. |
| Target / min SDK | Not confirmed. | Not stated in the content policy. | Bazaar checklist: https://developers.cafebazaar.ir/fa/guidelines/getting-started/launch-checklist | **Unknown.** The preset sets neither, so Godot 4.6.2 template defaults apply. Measure on the built APK (`aapt dump badging`). |
| CPU architectures | — | — | — | **Yes**: `arm64-v8a` + `armeabi-v7a`. |
| Signing | Every update must carry the same key (Android rule). | same | `signing/README.txt` in the project | **No.** `package/signed=false`; the only key is a *test* key stored inside the project folder. A release key does not exist. |
| Icon | Size/format not confirmed; Bazaar has a dedicated icon page and changed icon display in 1401. | Not confirmed. Rule 4: icon must not copy another app's. | https://developers.cafebazaar.ir/fa/guidelines/build-app/icon-design · https://developers.cafebazaar.ir/en/blog/update-on-icon-display | **No.** `icon.png` is 256x256, one file, no adaptive-icon layers set in the preset. It is also a generic chibi knight (see section d). |
| Screenshots (count, sizes) | Not confirmed. | Counts/sizes not in the policy. Rule 16: screenshots must match the real UI. Rule 5: no false information. | https://developers.cafebazaar.ir/fa/app-publish-guidelines/academy/app-detail · https://myket.ir/kb/en/pages/content-publishing-policy-2/ | **No.** Existing shots are 854x400 test captures (the game's internal viewport). Store shots must be taken on a real phone at its own resolution. |
| Feature graphic / promo image / video | Not confirmed. | Not confirmed. | Bazaar app-detail page (above) | **No.** None exists. |
| Listing text limits (name, short and full description) | Not confirmed. | Not confirmed. Rule 15: description must be complete, including Android version requirements. Rule 18: known device incompatibilities must be stated. | same | **Prepared** in `store_listing_fa.md` in three lengths; trim to the counter the panel shows. |
| Persian metadata | Not confirmed as a written rule. | Not stated in the policy. | — | **Yes in practice**: Persian name is set (`config/name_localized fa = اخگر و آهن`), full Persian listing is written. |
| Content / age rating | Not confirmed (whether a questionnaire, or an ESRA rating from the national games foundation, is required for an individual's mobile game). | Not specified in the policy. Rules 1, 2, 20: no sexual content, no "violent, racist, discriminatory" content, Iranian law applies. | https://myket.ir/kb/en/pages/content-publishing-policy-2/ | **Probably fine, unconfirmed.** Fantasy combat against divs, no blood I saw, no sexual content. Rule 2's wording on violence is broad; expect a reviewer's judgment. |
| Third-party content | Not confirmed. | Rule 7: a free app using others' content must fully describe those resources. Rule 8: a **paid** app using others' content needs the owners' approval; the developer is responsible. | Myket policy (above) | **Partly.** Audio credits and icon/font licences are in the project. I did not audit the licence of every sprite pack; this must be done before any paid model. |
| In-app payment SDK | Bazaar's library is Poolakey; whether its use is mandatory and whether an official Godot 4 plugin exists: not confirmed. | Rule 13: virtual goods, content or currency sold in an app **must** use Myket's in-app purchase system. Official Java/Kotlin guide exists; no Godot guide found. | https://myket.ir/docs/en/technical/iab/android/ · Myket policy (above) | **Not applicable today** (no purchases, no INTERNET permission). Adding payments means a Gradle build, an Android plugin per store, and two store-specific APKs. |
| Revenue share | Headline of Bazaar's own blog: Bazaar halves its share on sales up to an annual ceiling of 10 billion rials per developer. Base percentage, date, and whether it still holds in 2026: **not confirmed** (page unreadable). | Headline (Peivast, around April 2021): Myket cut its share to 15%. Current 2026 figure: **not confirmed**. | https://newsblog.cafebazaar.ir/commissioncut-lvl6dosebzbd · https://peivast.com/p/99140 | n/a |
| Payout rules, tax | Not confirmed. | Not confirmed. | Myket pricing page: https://myket.ir/docs/en/publishing-guide/preparing-app/pricing-and-discounts/ | n/a |
| Review time | Not confirmed. | Not specified. | — | n/a |
| Quality gate | Not confirmed. | Rule 17: runs without errors or force closes. Rule 18: tested on several devices. Rule 19: minimum quality in performance, appearance, content. | Myket policy (above) | **Unknown.** Automated tests pass; nobody has played 0.26.1 on a real phone (playtest summary, section 4, lists six things to look at on a device). |
| Privacy policy | Not confirmed whether a URL is mandatory. | Not explicitly required. Rule 11: no hidden network use. | Myket policy (above) | **Draft only.** `docs/privacy_policy.md` has `[...]` placeholders and is not hosted. Its claims match the build (only permission: vibrate). |
| Linking to other apps / stores | Not confirmed. | Rule 4: an app may not refer users to other apps. | Myket policy (above) | **Yes**, as far as I saw. Keep it that way: no "also on itch.io" link inside the Myket build. |
| Only Iranian apps may be sold | — | Rule 21. | Myket policy (above) | **Yes.** |

## b. Blockers, in order

"Agents" = the director's team. "Milad" = things only the developer can do, because they need his identity, his device, or his secrets.

| # | Blocker | Who |
|---|---|---|
| 1 | **Release signing key.** Create it on Milad's own computer, password known only to him, two offline backups. The test key in `signing/` must never sign a store build: it sits in the project folder and has been readable by every agent. Lose or leak the release key and the game can never be updated under the same listing. | **Milad** (agents write the exact steps) |
| 2 | **Developer accounts** on Bazaar and Myket in his own name, with whatever identity and bank details each panel asks for. Exact documents unconfirmed; the panel will say. Start now, verification can take days. | **Milad** |
| 3 | **Art licence audit.** One table: every sprite sheet, tile set, font, sound, track → source, licence, proof. Myket rules 7 and 8 make this a publishing condition, and rule 8 makes it stricter if the game is ever paid. | Agents (table) · Milad (keeps receipts/links) |
| 4 | **Icon.** A new master at high resolution plus Android adaptive layers, set in the export preset. The current one is 256 px and shows a generic knight. | Agents can build it · Milad approves the look |
| 5 | **A real release build, measured.** Export, sign with the new key, then record: APK size, min/target SDK, both ABIs present, install and cold start on a phone. Compare against the limits read from the two official pages. | Agents (build recipe, checks) · Milad (signs, installs) |
| 6 | **Real-device pass.** At least two phones, one of them old/cheap (32-bit if possible): the six checks in the playtest summary section 4, a full chapter 1, save/quit/resume, Persian text. Myket rules 17 to 19. | **Milad** |
| 7 | **Store screenshots and one banner** at phone resolution, Persian UI, following the shot list in `store_listing_fa.md`. | Milad (captures) · Agents (crop, captions, banner) |
| 8 | **Privacy policy online.** Fill the two placeholders (name, contact e-mail), host on a free public page, put the URL in both listings. A dedicated support e-mail is needed anyway. | Agents (page) · Milad (account, e-mail) |
| 9 | **Monetisation decision before the first upload** (section c). It decides whether the build needs internet permission, a payment plugin and a changed privacy text. | **Milad**, on the director's recommendation |
| 10 | **Read the unconfirmed rules** in a browser and fill the "not confirmed" cells: size limit, icon and screenshot specs, text limits, age-rating step, revenue share, payout. | Milad or the director, 10 to 20 minutes |
| 11 | Listing text pasted and trimmed to the panels' counters; category chosen; Android version and "tested on" line completed (Myket rule 15/18). | Agents (text is ready) · Milad (pastes) |

Not a blocker for submission, but it is the reason the critic holds store readiness at 5.5/10: the art does not look like the Shahnameh (section d).

## c. Monetisation

Information for the developer's decision, not financial advice. Revenue shares and payout terms are unconfirmed (section a).

| Model | What it takes | For | Against, for a solo developer in Iran |
|---|---|---|---|
| **Premium (paid download)** | No SDK. Price set in the panel. | Technically the cheapest. Keeps "offline, no ads, no internet permission" literally true. | An unknown developer asks for money before a single minute of play; nobody can try it. Myket rule 8 applies in full (owner approval for third-party content in paid apps). Paid APKs get copied to mod sites quickly; a search for an older paid Shahnameh game returned a "hacked version" blog on the first page. |
| **Free, one-time "full game" unlock after chapter 1** | Gradle build, an Android payment plugin for Godot 4, **two builds** (Bazaar's library, Myket's library), INTERNET permission, updated privacy policy, a purchase-restore path, testing real payments. | Fits this game best: chapter 1 (Zabol, Rostam's training, the first echoes) is a complete, honest demo. One purchase, no pressure mechanics, consistent with the game's tone. | The largest engineering job on this list, in an area where Milad cannot debug alone. An offline unlock flag is easy to crack. Every store update must be tested twice. |
| **Cosmetic purchases** (hero looks) | Same payment work as above. | Does not gate story. | The 12 or so looks are currently *earned* by achievements; selling them removes a reward loop players liked. Cosmetics sell in games with large, social audiences; this is a single-player offline game with no audience yet. Lowest expected return for the same engineering. |
| **Rewarded ads** | An ad SDK from an Iranian network, internet, consent text, placements (revive, extra potion). | Earns from players who will never pay. | Kills the cleanest line on the store page ("no ads, fully offline"). Needs volume to matter. Adds a third-party SDK that collects data, so the privacy policy stops being one paragraph. Ad income per view on Iranian networks: not researched, unknown. |

**Recommendation: two steps.**

1. **Launch free and complete, with no payments at all**, labelled as an early version, on Myket and Bazaar. Reasons: it ships with the build that exists (no SDK, no internet permission, privacy policy stays true); it removes the riskiest engineering from the first submission; a first-time developer learns both review processes with nothing at stake; and the game's real problem right now is that nobody knows it, which a price makes worse. The first month's goal is ratings, written reviews and how far players get, not income.
2. **If the numbers justify it** (people finishing chapter 1 and reviewing well), add the **one-time full-game unlock** in a later version: chapter 1 stays free forever, chapters 2 and 3 with the Boss Rush and New Game+ sit behind one purchase, and every player who installed during the free period keeps everything. Announce that promise on day one so nobody feels something was taken away.

Do not add ads. Do not sell looks.

Two cautions outside the two Iranian stores: itch.io can carry a free build with no trouble, but receiving money from itch.io or Steam as a resident of Iran runs into payment and sanctions restrictions. I did not research this; it must be checked before any plan that counts on that income.

## d. Positioning

**One sentence:** An offline action RPG in the world of the Shahnameh, where you learn each hero's own move from Rostam himself and hunt the echoes of the divs he once slew, from Zabol to Damavand.

**Three selling points**
1. **The Shahnameh as a place, not a costume.** Rostam trains you, Zal sends you out, Gordafarid, Siavash, Sindokht and Rudabeh live in the village, and each of the four callings fights with a move taken from the epic: the lasso, the Simorgh's feather, the khadang arrow, the walk through fire.
2. **A whole game, offline, with nothing to sell you.** Three chapters, four difficulty levels including a story mode, seven puzzle shrines, a boss rush, New Game+, bounties and a wave trial. No ads, no internet, no account.
3. **Written in Persian first.** Right-to-left interface, dialogue edited by a critic over three rounds; English included.

**Nearest competitors** (found by search; I could read only titles and store URLs, not the pages, so genre details, prices and install counts are unverified):

| Game | Where | What the title tells us |
|---|---|---|
| نامداران – همراه اساطیر بجنگ | https://myket.ir/app/ir.morvarid.namdaran (also on Bazaar) | "Fight alongside the myths": Persian-myth heroes as the hook. |
| هفتخان رستم (نبرد مازندران) | https://myket.ir/app/com.PT.RostamBOMFree | Rostam's Seven Labours, free edition. |
| شیردل | https://cafebazaar.ir/app/ir.gamelife.shirdelpaid | Iranian action title; the package name suggests a paid edition. |
| رستم‌نامه ۱؛ هفت خان | https://www.ircg.ir/fa/game/85/ | Older Seven Labours game listed by the national games foundation. |
| هشت خان | https://www.mehrnews.com/news/6995341/ | A mobile game "that revives the myths", covered by national news agencies. |
| هفت‌خوان: سوگندِ سپیده | https://github.com/aliv87m-web/haft-khan-sogand-sepideh | Another solo 2D Android action game on the Seven Labours, in development. |

How we differ, stated carefully: all of these sell **Rostam's Seven Labours with Rostam as the hero**. Ours is set *after* the labours, with Rostam as teacher and witness and a new hero; it is a full top-down RPG with four classes rather than a retelling. That is a real difference in the pitch. It is also a risk: the search term everyone types is «هفت خوان رستم», and our title, «اخگر و آهن», contains neither word. The subtitle and the first line of the description must carry «شاهنامه» and «رستم».

**The three biggest marketing weaknesses, as the build looks in the screenshots**

1. **It does not look Iranian.** The hero is a chibi boy with a red headband and a blue toy sword; Zal is a bald wizard in a purple robe; the Sage wears a pointed Western wizard hat; Rostam has the hero's face and no mace or tiger-skin. The grass, pines and cottages are a familiar free tileset look. Remove the Persian text and nothing in any frame says Shahnameh. The store page promises Ferdowsi and the pictures show a generic fantasy asset pack; that gap is where bad reviews come from. The icon has the same problem and is the first thing anyone sees.
2. **The screenshots are mostly interface.** In a typical frame the joystick, nine round buttons, minimap, objective box, achievement card and health panel cover roughly half the picture, and the hero is a few dozen pixels tall. At thumbnail size a store visitor sees buttons, not a game. Only the boss title cards (for example the White Div, letterboxed, name in large type) read as a "moment".
3. **There is no key image and no searchable name.** No logo, no painted or composed banner, no trailer, no feature graphic; the title has no keyword; version "0.26.1" signals unfinished. A no-budget game survives on one strong image and one clear sentence, and today it has the sentence only.

What can be done without touching the game: lead with the boss cards and dialogue shots, capture with the pad hidden if the game allows it (if not, that is a request for the director, not for me), and build the banner from typography and a silhouette of Damavand rather than from the sprites.

## e. Zero-budget launch plan, first 30 days

Timing: the longest night, **Yalda (about 21 December)**, is a night when families read the Shahnameh aloud. Today is 12 November. If blockers 1 to 8 close by early December, release in the week before Yalda and use it as the peg. If they do not, do not rush a broken build for the date; the same plan works from any day 0.

**Before day 0 (needs no build)**
- Open one Telegram channel and one Instagram page under the game's name; pin the one-sentence pitch and the privacy/contact link. Open an Aparat channel for video.
- Record on a phone: three clips of 15 to 25 seconds, one idea each: Rostam teaching the lasso; a boss card and the kill banner («به خاک برگشت»); the four calling cards. Vertical crop with a Persian caption burned in.
- Write one honest post for Virgool: "I had no programming background and made a Shahnameh game", with what went wrong. Developer stories travel further than adverts.
- Make a press page: pitch, five screenshots, the three clips, the APK link, contact.

**Days 1 to 3: release**
- Publish on Myket first, Bazaar as soon as its review passes. Same day: the Virgool post, the three clips on Instagram Reels and Aparat, the Telegram channel announcement.
- Ask each store's developer support, through the panel's ticket system, whether there is a list or shelf for Iranian-made or indie games and how to be considered. One polite message each; it costs nothing.
- Personal network: ask 20 real people to install, play chapter 1 and write an honest review. Never buy or trade reviews; Myket rule 12 bans purchased reviews and downloads.

**Days 4 to 10: outreach**
- E-mail the press page to the Persian games press that covers mobile and Iranian titles (Zoomg publishes a "best Iranian Android games" list; also Vigiato, Digiato, Gamefa, Bazinama). One short personal e-mail each, subject line with «شاهنامه».
- Message 15 to 20 small and mid-size Persian gaming creators on Aparat, Instagram and YouTube with a build and a one-line pitch. Pick ones who play indie or Iranian games; skip the largest.
- Post in Persian game-developer communities (Telegram groups, Discord servers, the indie threads on X) as a peer asking for feedback, not as an advert.
- Reach outside gaming: Shahnameh-reading pages, Persian literature teachers and students, storytellers. This audience has no other game to share and the hook is theirs.

**Days 11 to 20: respond in public**
- Reply to every store review. Ship one update that fixes the three most repeated complaints and say so in "what's new" with the reviewers' own words.
- One short clip per calling per week ("the way of Gordafarid"), each ending on the store link.
- Yalda post if the date fits: Rostam's line on the White Div over gameplay, "this Yalda, read the Shahnameh, then play it".

**Days 21 to 30: measure and decide**
- From the panels: installs, rating, number of written reviews, uninstall rate if shown. From reviews and messages: how many mention finishing chapter 1.
- Publish a second Virgool post with the real numbers. Upload the same build to itch.io with the English listing.
- Decide on step 2 of the monetisation plan, and on whether the next money or effort should go to art (my view: yes, the hero, Rostam, Zal and the icon, before anything else).

## Sources

Official, read: Myket Content Publishing Policy — https://myket.ir/kb/en/pages/content-publishing-policy-2/

Official, located but not readable by my tools (open in a browser):
- https://developers.cafebazaar.ir/fa/guidelines/getting-started/launch-checklist
- https://developers.cafebazaar.ir/fa/guidelines/developers-panel/app-release
- https://developers.cafebazaar.ir/fa/guidelines/developers-panel/overview
- https://developers.cafebazaar.ir/fa/app-publish-guidelines/academy/app-detail
- https://developers.cafebazaar.ir/fa/guidelines/build-app/icon-design
- https://developers.cafebazaar.ir/fa/guidelines/feature/expansion-files
- https://developers.cafebazaar.ir/fa/guidelines/feature/device-specification
- https://newsblog.cafebazaar.ir/commissioncut-lvl6dosebzbd
- https://myket.ir/kb/en/topics/publishing-guide/
- https://myket.ir/docs/en/publishing-guide/preparing-app/pricing-and-discounts/
- https://myket.ir/docs/en/technical/iab/android/
- https://developer.myket.ir/

Secondary, headline only: https://peivast.com/p/99140 · https://www.zoomit.ir/tech-iran/370016-myket-decreasing-revenue-share/ · https://www.zoomit.ir/tech-iran/369835-bazaar-decreasing-revenue-share-impact/

Competitor links are in section d.
