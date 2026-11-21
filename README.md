# Divslayer | دیوکش

A Persian-mythology-inspired action RPG made with Godot.

یک بازی اکشن نقش‌آفرینی با الهام از شاهنامه و اسطوره‌های ایرانی، ساخته‌شده با Godot.

[![Godot CI](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml/badge.svg?branch=main)](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml)

**Status / وضعیت:** The project is under development. The current project version remains **0.43.0**; the latest recorded `main` commit is `7decddb22cf4ab4b55da9347e7d6a82a5e72eb6b`. Godot CI run [457](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44904064171) passed all four headless shards, and multi-tool production run [348](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44904064227) passed lint, artwork/map and audio checks. The latest Android QA run [201](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44904064251) exported and signature-verified the isolated `0.43.0-qa` APK and installed it in the emulator, but failed its final startup assertion because it searched for `OnGodotMainLoopStarted`; the captured Godot 4.7.2 log contains `OnGodotSetupCompleted` and shows the app still in the foreground. The corrected workflow passed in [Android QA run 202](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44905519384), including emulator install, launcher, Godot setup marker, foreground retention and screenshot capture. Installable artifact [14707328088](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44905519384/artifacts/14707328088) expires 5 December 2026; APK SHA-256: `1089b7fc3d07057b001af6c4049137f9245ba6fc348d88beab0088b8c3e9bf3b`. The workflow correction is in [PR #56](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/56), which remains open for review/merge. This is a debug-signed QA build, not a production release. Chapter IV, the High Eyrie/Gale Warden work, weather ambience, dodge trails and Thornwood fix are now integrated into `main` through merged PRs [#37](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/37) and [#38](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/38).

**وضعیت:** پروژه همچنان در حال توسعه است. نسخهٔ فعلی پروژه **0.43.0** است و آخرین commit ثبت‌شده روی شاخهٔ `main` برابر با `7decddb22cf4ab4b55da9347e7d6a82a5e72eb6b` است. آزمون Godot در اجرای [شمارهٔ 457](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44904064171) هر چهار بخش تست headless را با موفقیت گذرانده و خط لولهٔ چندابزاری در اجرای [شمارهٔ 348](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44904064227) موفق بوده است. در اجرای اخیر Android QA به شمارهٔ [201](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44904064251)، فایل APK آزمایشی `0.43.0-qa` ساخته و امضای آن تأیید شد و روی شبیه‌ساز نصب گردید؛ اما شرط پایانی بررسی اجرا به‌دلیل جست‌وجوی رویداد اشتباه `OnGodotMainLoopStarted` شکست خورد. لاگ واقعی Godot 4.7.2 رویداد `OnGodotSetupCompleted` را ثبت کرده و Activity بازی را در پیش‌زمینه نشان می‌دهد. اصلاح خط لوله در اجرای [Android QA شمارهٔ 202](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44905519384) موفق شد: نصب در شبیه‌ساز، اجرای لانچر، ثبت رویداد شروع Godot، ماندن برنامه در پیش‌زمینه و ثبت اسکرین‌شات همگی موفق بودند. artifact نصب‌پذیر [14707328088](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44905519384/artifacts/14707328088) تا ۵ دسامبر ۲۰۲۶ در دسترس است؛ SHA-256 فایل APK: `1089b7fc3d07057b001af6c4049137f9245ba6fc348d88beab0088b8c3e9bf3b`. اصلاح workflow در [PR شمارهٔ 56](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/56) قرار دارد و هنوز برای بازبینی/ادغام باز است. این خروجی QA با کلید موقت debug امضا شده و نسخهٔ انتشار رسمی نیست. فصل چهارم، منطقهٔ High Eyrie و باس Gale Warden، باد محیطی، ردّ باد جاخالی و اصلاح Thornwood با ادغام PRهای [37](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/37) و [38](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/38) اکنون در `main` قرار دارند.

## Repository history / تاریخچه مخزن

On 18 November 2026, the `main` branch history was rewritten to remove an old sample signing password from historical developer notes. Anyone with a clone created before that date should make a fresh clone before contributing; do not merge or push the old clone's history back into `main`. Back up any uncommitted personal work separately first.

در ۱۸ نوامبر ۲۰۲۶ تاریخچه شاخهٔ `main` برای حذف یک گذرواژهٔ نمونه از یادداشت‌های قدیمی بازنویسی شد. اگر پیش از این تاریخ مخزن را clone کرده‌اید، پیش از هر مشارکت clone تازه بگیرید؛ تاریخچهٔ clone قدیمی را دوباره با `main` ادغام یا push نکنید. ابتدا از تغییرات شخصیِ commit‌نشده جداگانه پشتیبان تهیه کنید.

## Development documents / اسناد توسعه

- [Release readiness](docs/RELEASE_READINESS.md) — current Android, rights, legal, and security blockers.
- [Integration review — 20 November 2026](docs/INTEGRATION_REVIEW_2026-11-20.md) — coordination status for PRs #25, #26, and #36.
- [Chapter IV wind system](docs/CHAPTER_04_WIND_SYSTEM_IMPLEMENTATION.md) — implemented controller and remaining gameplay integration.
- [Alborz art production brief](docs/ALBORZ_ART_PRODUCTION_BRIEF.md) — dedicated environment and scout asset requirements.
- [Animation pipeline audit](docs/ANIMATION_PIPELINE.md) — current atlas facts and runtime limits.
- [Animation production plan](docs/ANIMATION_PRODUCTION_PLAN.md) — real multi-frame work for Warrior, Mage, Rogue, and Paladin.
- [Art direction guide](docs/ART_DIRECTION_GUIDE.md) — visual identity, character/creature/environment design, and Godot sprite standards.
- [Class visual design](docs/CLASS_VISUAL_DESIGN.md) — class identities, combat animation beats, and sprite-sheet requirements.
- [Asset pipeline](docs/ASSET_PIPELINE.md) — image/audio integrity checks and the artwork rights-register workflow.
- [Multi-tool production pipeline](docs/MULTITOOL_PIPELINE.md) — GDScript/Python analysis, FFmpeg audio checks, image inspection, and map-layout previews.
- [Creative applications workflow](docs/CREATIVE_TOOLS.md) — Krita, Audacity, LMMS, and Blender smoke tests and source-project handling.


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
