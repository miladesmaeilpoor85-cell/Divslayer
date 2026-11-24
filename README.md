# Divslayer | دیوکش

A Persian-mythology-inspired action RPG made with Godot.

یک بازی اکشن نقش‌آفرینی با الهام از شاهنامه و اسطوره‌های ایرانی، ساخته‌شده با Godot.

[![Godot CI](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml/badge.svg?branch=main)](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml)

**Status / وضعیت:** The project remains under development. Version: **0.43.0**. Current `main` commit: `6fdc3c5176fbf87b07d59e1910fcdce26ebf4df2`. Godot 4.7.2 CI [run 44906428789](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428789) passed all four headless test shards. The corrected Android QA workflow also passed on `main` in [run 44906428530](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428530); it exported and signature-verified the isolated `0.43.0-qa` APK, installed/launched it in the emulator, detected `OnGodotSetupCompleted`, kept the app activity in the foreground, found no fatal/script-error/ANR markers, and captured a launch screenshot. The captured screenshot shows the Godot splash screen, not a gameplay or title-menu sign-off. Installable artifact [14707913866](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428530/artifacts/14707913866) expires **5 December 2026**. APK SHA-256: `2fbddeaff8576041590ce6d9db4d9c67b9b42ed3dcdf29c492df59a1824aa751`. This debug-signed QA package is not a production release. See [the current external tester guide](docs/ANDROID_EXTERNAL_TESTING.md). Chapter IV and High Eyrie/Gale Warden remain integrated through merged PRs [#37](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/37) and [#38](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/38).

**وضعیت:** پروژه همچنان در حال توسعه است. نسخهٔ فعلی **0.43.0** و commit فعلی `main` برابر `6fdc3c5176fbf87b07d59e1910fcdce26ebf4df2` است. آزمون Godot 4.7.2 در اجرای [44906428789](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428789) هر چهار بخش تست headless را با موفقیت گذرانده است. گردش‌کار اصلاح‌شدهٔ Android QA نیز روی `main` در اجرای [44906428530](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428530) موفق شد: APK آزمایشی `0.43.0-qa` ساخته و امضای آن تأیید شد، روی شبیه‌ساز نصب و اجرا شد، نشانگر `OnGodotSetupCompleted` ثبت شد، Activity بازی در پیش‌زمینه ماند، هیچ نشانگر خطای fatal/script یا ANR در لاگ ثبت نشد و تصویر اجرا ذخیره شد. تصویر این اجرا صفحهٔ آغاز Godot را نشان می‌دهد؛ تأیید منوی اصلی یا گیم‌پلی نیست. فایل نصب‌پذیر [Artifact 14707913866](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428530/artifacts/14707913866) تا **۵ دسامبر ۲۰۲۶** نگهداری می‌شود. SHA-256 فایل APK برابر است با `2fbddeaff8576041590ce6d9db4d9c67b9b42ed3dcdf29c492df59a1824aa751`. این بسته با کلید موقت Debug امضا شده و نسخهٔ انتشار رسمی نیست. راهنمای به‌روز تست‌کنندگان در [این سند](docs/ANDROID_EXTERNAL_TESTING.md) قرار دارد. فصل چهارم و منطقهٔ High Eyrie همراه با باس Gale Warden همچنان در شاخهٔ اصلی ادغام شده‌اند.

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
- [Quality-first production policy](docs/QUALITY_FIRST_POLICY.md) — visual/audio/animation quality takes precedence over package size.
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
