# Divslayer | دیوکش

A Persian-mythology-inspired action RPG made with Godot.

یک بازی اکشن نقش‌آفرینی با الهام از شاهنامه و اسطوره‌های ایرانی، ساخته‌شده با Godot.

[![Godot CI](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml/badge.svg?branch=main)](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml)

**Status / وضعیت:** The project remains under development. Version: **0.43.0**. Latest main commit: `29216952e387c8047cfb05aca92700f8f71605bd`. Godot 4.7.2 CI [run 45724516353](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45724516353) passed all four headless test shards, and the multi-tool pipeline [run 45724516398](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45724516398) passed GDScript/Python lint, image/map preview, and audio checks on the same main commit. Open draft work remains separate from main: PR #65 natural-player run [45726750227](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227) now passed for all four classes, each with 15/15 assertions and zero QA findings; it covered seven checkpoints across five maps in Chapters I–II and defeated Arzhang and Anvilward, but did not verify full-game completion or physical-device usability. Its four evidence artifacts (121 screenshots total) are [Mage](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227/artifacts/15076161282), [Paladin](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227/artifacts/15075332320), [Warrior](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227/artifacts/15075306476), and [Rogue](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227/artifacts/15074044767), expiring 10 December 2026. PRs #66 and #67 have passing technical pipelines but still require human visual approval; PR #64 now passes all four Godot shards, a live Wyrm's Hollow/Frostknight collision integration test, and Android QA APK export/signature/emulator launch on head 194a38b919ec0d2669ecb50abbc38664ebd3d5fe; physical-device review remains outstanding. A QA APK was exported from the PR #65 branch (not main): [artifact 15075470879](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750222/artifacts/15075470879), retained until **10 December 2026**. This debug-signed QA package is not a production release and is not proof of full-game completion or physical-device acceptance. See [the current development status](docs/DEVELOPMENT_STATUS_2026-11-26.md) and [the external tester guide](docs/ANDROID_EXTERNAL_TESTING.md).

**وضعیت:** پروژه همچنان در حال توسعه است. نسخهٔ فعلی **0.43.0** و آخرین Commit شاخهٔ main برابر `29216952e387c8047cfb05aca92700f8f71605bd` است. آزمون Godot 4.7.2 در اجرای [45724516353](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45724516353) هر چهار بخش headless را با موفقیت گذرانده و خط لولهٔ چندابزاری در اجرای [45724516398](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45724516398) بررسی GDScript و Python، تصاویر و پیش‌نمایش نقشه‌ها و فایل‌های صوتی را با موفقیت انجام داده است. کارهای Draft هنوز از main جدا هستند: آزمون طبیعی PR شمارهٔ ۶۵ در اجرای [45726750227](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227) اکنون برای هر چهار کلاس موفق شده و هر کلاس ۱۵ آزمون از ۱۵ آزمون را بدون خطای QA گذرانده است؛ این آزمون هفت نقطهٔ کنترل در پنج نقشه از فصل‌های اول و دوم را پوشش داده و Arzhang و Anvilward را شکست داده، اما تکمیل کل بازی یا تجربهٔ گوشی واقعی را تأیید نمی‌کند. چهار بستهٔ مدرک با مجموع ۱۲۱ تصویر برای [Mage](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227/artifacts/15076161282)، [Paladin](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227/artifacts/15075332320)، [Warrior](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227/artifacts/15075306476) و [Rogue](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750227/artifacts/15074044767) تا ۱۰ دسامبر ۲۰۲۶ در دسترس‌اند. PRهای ۶۶ و ۶۷ آزمون فنی موفق دارند اما تأیید بصری انسانی لازم دارند؛ در PR شمارهٔ ۶۴، هر چهار shard آزمون Godot، آزمون زندهٔ ساخت Wyrm's Hollow و برخورد Frostknight، و خروجی/امضا/نصب و اجرای APK آزمایشی روی شبیه‌ساز موفق شده‌اند؛ بازبینی روی گوشی فیزیکی هنوز باقی است. یک APK آزمایشی از شاخهٔ PR شمارهٔ ۶۵ (نه main) ساخته شده است: [Artifact 15075470879](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45726750222/artifacts/15075470879) که تا **۱۰ دسامبر ۲۰۲۶** نگهداری می‌شود. این بسته با کلید موقت Debug امضا شده و نسخهٔ انتشار رسمی نیست؛ همچنین تأییدکنندهٔ تکمیل کل بازی یا تست روی گوشی واقعی نیست. [گزارش وضعیت توسعه](docs/DEVELOPMENT_STATUS_2026-11-26.md) و [راهنمای تست اندروید](docs/ANDROID_EXTERNAL_TESTING.md) را ببینید.
**Current verification update / به‌روزرسانی تازهٔ بررسی:** The owner has now downloaded, installed and manually smoke-tested the QA APK from [Android QA run 45739638019](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45739638019) on a physical Android phone and reported that the tested experience was good. This is an owner-reported device smoke test, not a full compatibility/performance matrix or full-campaign test. The later four-class run [45739638074](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45739638074) on the then-current PR #65 head passed Warrior, Rogue and Paladin but failed Mage while clearing a remaining forest enemy: the report showed four combat attempts without a registered hit. A test-agent line-of-sight reposition fix and five policy tests have since been added on PR #65 head `97527a78b75d40f7a05e669ab63c1a84e73b8978`; Godot CI [45742250743](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45742250743) passed, while fresh four-class journeys and Android QA are still running. This supersedes the earlier all-four-classes-passed statement above until the new evidence is reviewed. PR #66's Warden art-detail/motion revision has Godot, Multi-tool and Creative Tools checks passed on head `eb514f5700776d14e6093168b0ad1d27a163b71e`; Android QA is still running. PR #67's winding/variable-width ground-route revision is under fresh validation on head `41b9fcb771de56e928958322c6060a17b5b58628`. Both art PRs remain Draft, unmerged and not finally visually approved. The 403 image and 30 music rights entries remain `UNVERIFIED`.

**به‌روزرسانی تازهٔ بررسی:** مالک پروژه APK آزمایشیِ اجرای [Android QA شمارهٔ 45739638019](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45739638019) را دانلود، روی گوشی واقعی نصب و به‌صورت دستی آزمایش کرده و گزارش داده تجربهٔ آزمایش‌شده خوب بوده است. این تأیید دستیِ نصب و اجرای اولیه است، نه آزمون کامل سازگاری و کارایی همهٔ دستگاه‌ها یا اتمام کمپین. اجرای بعدی چهار کلاس [45739638074](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45739638074) روی Head قبلی PR شمارهٔ ۶۵ برای Warrior، Rogue و Paladin موفق شد، اما Mage هنگام پاک‌سازی دشمن باقی‌مانده در جنگل شکست خورد؛ گزارش چهار تلاش بدون ضربهٔ ثبت‌شده را نشان داد. پس از آن، اصلاح جابه‌جایی Mage برای پیدا کردن خط دید و پنج آزمون سیاستی روی Head جدید PR شمارهٔ ۶۵ با شناسهٔ `97527a78b75d40f7a05e669ab63c1a84e73b8978` ثبت شد؛ آزمون Godot در [45742250743](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/45742250743) موفق شده، اما اجرای تازهٔ چهار کلاس و Android QA هنوز در جریان است. این وضعیت تا زمان بررسی مدرک تازه، ادعای موفقیت قبلی هر چهار کلاس را موقتاً جایگزین می‌کند. اصلاح جزئیات و حرکت Warden در PR شمارهٔ ۶۶ در آزمون‌های Godot، Multi-tool و Creative Tools روی Head `eb514f5700776d14e6093168b0ad1d27a163b71e` موفق شده و Android QA هنوز در جریان است. اصلاح مسیرهای زمین در PR شمارهٔ ۶۷ روی Head `41b9fcb771de56e928958322c6060a17b5b58628` در حال اعتبارسنجی است. هر دو PR هنری هنوز Draft، ادغام‌نشده و فاقد تأیید نهایی بصری هستند. وضعیت حقوق ۴۰۳ تصویر و ۳۰ قطعهٔ موسیقی همچنان `UNVERIFIED` است.

## Repository history / تاریخچه مخزن

On 18 November 2026, the `main` branch history was rewritten to remove an old sample signing password from historical developer notes. Anyone with a clone created before that date should make a fresh clone before contributing; do not merge or push the old clone's history back into `main`. Back up any uncommitted personal work separately first.

در ۱۸ نوامبر ۲۰۲۶ تاریخچه شاخهٔ `main` برای حذف یک گذرواژهٔ نمونه از یادداشت‌های قدیمی بازنویسی شد. اگر پیش از این تاریخ مخزن را clone کرده‌اید، پیش از هر مشارکت clone تازه بگیرید؛ تاریخچهٔ clone قدیمی را دوباره با `main` ادغام یا push نکنید. ابتدا از تغییرات شخصیِ commit‌نشده جداگانه پشتیبان تهیه کنید.

## Development documents / اسناد توسعه

- [Release readiness](docs/RELEASE_READINESS.md) — current Android, rights, legal, and security blockers.
- [External Android testing](docs/ANDROID_EXTERNAL_TESTING.md) — current verified QA APK, checksum, installation notes, and tester checklist.
- [Production Android release setup](docs/ANDROID_RELEASE_SETUP.md) — private identity/signing checklist; no production signing workflow is enabled.
- [Integration review — 20 November 2026](docs/INTEGRATION_REVIEW_2026-11-20.md) — coordination status for PRs #25, #26, and #36.
- [Chapter IV wind system](docs/CHAPTER_04_WIND_SYSTEM_IMPLEMENTATION.md) — implemented controller and remaining gameplay integration.
- [Alborz art production brief](docs/ALBORZ_ART_PRODUCTION_BRIEF.md) — dedicated environment and scout asset requirements.
- [Animation pipeline audit](docs/ANIMATION_PIPELINE.md) — current atlas facts and runtime limits.
- [Animation production plan](docs/ANIMATION_PRODUCTION_PLAN.md) — real multi-frame work for Warrior, Mage, Rogue, and Paladin.
- [Visual upgrade program](docs/VISUAL_UPGRADE_PROGRAM.md) — staged character, combat, VFX, and Alborz art priorities.
- [Art direction guide](docs/ART_DIRECTION_GUIDE.md) — visual identity, character/creature/environment design, and Godot sprite standards.
- [Class visual design](docs/CLASS_VISUAL_DESIGN.md) — class identities, combat animation beats, and sprite-sheet requirements.
- [Asset pipeline](docs/ASSET_PIPELINE.md) — image/audio integrity checks and the artwork rights-register workflow.
- [Asset-rights evidence requirements](docs/ASSET_RIGHTS_EVIDENCE_REQUEST.md) — per-file proof needed for AI art, Suno/Hoosha music, CC0 audio, fonts and icons.
- [Multi-tool production pipeline](docs/MULTITOOL_PIPELINE.md) — GDScript/Python analysis, FFmpeg audio checks, image inspection, and map-layout previews.
- [Creative applications workflow](docs/CREATIVE_TOOLS.md) — Krita, Audacity, LMMS, and Blender smoke tests and source-project handling.
- [Google Flow cinematic production pack](docs/GOOGLE_FLOW_PRODUCTION_PACK.md) — a bilingual teaser shot plan and prompt pack; generation remains a manual task in the owner's Flow account.
- [Gemini Omni video generation](docs/GEMINI_OMNI_VIDEO_SETUP.md) — a manual, cost-controlled GitHub Actions workflow; generation requires an owner-configured `GEMINI_API_KEY` secret and is never triggered by pull-request validation.


## Current combat animation status / وضعیت فعلی انیمیشن مبارزه

The production manifest now has six multi-frame directional light-attack clips: Warrior Starter and Rogue Starter, each with four frames in down/up/side directions. Mage and Paladin still need authored Starter attack frames, and the other 30 directional attacks remain one-pose clips. Six-pose class illustrations in the menu/hero folio are not gameplay combat animation. See [the animation pipeline audit](docs/ANIMATION_PIPELINE.md).

در Manifest فعلی شش کلیپ حملهٔ سبکِ چندفریمی ثبت شده است: Warrior Starter و Rogue Starter، هرکدام با چهار فریم در سه جهت پایین، بالا و نیم‌رخ. برای Mage و Paladin هنوز فریم‌های اختصاصی حملهٔ Starter لازم است و ۳۰ کلیپ جهت‌دار دیگر همچنان تک‌فریمی‌اند. تصاویر شش‌حالتهٔ کلاس‌ها در منو و دفترچهٔ قهرمان، انیمیشن مبارزهٔ داخل بازی محسوب نمی‌شوند. جزئیات در [ممیزی خط لولهٔ انیمیشن](docs/ANIMATION_PIPELINE.md) آمده است.

## Goals / اهداف

- Share project progress and receive feedback from the community.
- Keep official publishing, distribution, branding, and release decisions under the project owner's control.

- نمایش روند پیشرفت پروژه و دریافت بازخورد از جامعه.
- حفظ کنترل انتشار رسمی و تصمیم‌های تجاری نزد مالک پروژه.

## Community feedback / بازخورد جامعه

You are welcome to report bugs, suggest features, and discuss the project through GitHub Issues. **Please do not submit code, art, audio, or other pull requests for inclusion at this time.** The contributor terms and third-party asset review are not yet finalized. This notice will be updated when a clear, reviewed contribution process is ready.

از ثبت باگ، پیشنهاد قابلیت و گفت‌وگو درباره پروژه در بخش Issues استقبال می‌شود. **لطفاً در حال حاضر درخواست ادغام شامل کد، تصویر، صدا یا سایر مشارکت‌ها ارسال نکنید.** شرایط مشارکت و بررسی مجوز دارایی‌های اشخاص ثالث هنوز نهایی نشده است. پس از آماده‌شدن روند روشن و بررسی‌شده، این اطلاعیه به‌روزرسانی خواهد شد.

## Release and asset records / انتشار و سوابق دارایی‌ها

See [release readiness](docs/RELEASE_READINESS.md) and the [per-file image rights register](docs/ASSET_RIGHTS_REGISTER.csv) for verified status and outstanding release checks.

برای مشاهده وضعیت انتشار و موارد باقی‌مانده، [چک‌لیست آمادگی انتشار](docs/RELEASE_READINESS.md) و [فهرست حقوق تک‌تک تصاویر](docs/ASSET_RIGHTS_REGISTER.csv) را ببینید.

## License / مجوز

**Source-available, not open source.** Public access does not grant redistribution, modified-build publication, commercial use, or asset-reuse rights. See [LICENSE](LICENSE). Third-party materials remain subject to their own licenses.

**کد منبع قابل مشاهده است، اما پروژه متن‌باز نیست.** عمومی‌بودن مخزن به‌خودی‌خود اجازه بازتوزیع، انتشار نسخه تغییریافته، استفاده تجاری یا استفاده مجدد از دارایی‌ها را نمی‌دهد. فایل [LICENSE](LICENSE) را ببینید. دارایی‌های اشخاص ثالث تابع مجوزهای خود هستند.

## Security / امنیت

Signing keys, certificates, passwords, API tokens, and private data must never be committed. The published source was prepared to exclude signing material and generated build files, but contributors should still review changes carefully. See [SECURITY.md](SECURITY.md).

هرگز کلیدهای امضا، گواهی‌ها، رمزهای عبور، توکن‌های API یا اطلاعات خصوصی را در مخزن قرار ندهید. سورس منتشرشده برای کنارگذاشتن فایل‌های امضا و خروجی‌های تولیدی آماده شده است؛ بااین‌حال همه تغییرات باید با دقت بررسی شوند. فایل [SECURITY.md](SECURITY.md) را ببینید.
