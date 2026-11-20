# Divslayer | دیوکش

A Persian-mythology-inspired action RPG made with Godot.

یک بازی اکشن نقش‌آفرینی با الهام از شاهنامه و اسطوره‌های ایرانی، ساخته‌شده با Godot.

[![Godot CI](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml/badge.svg?branch=main)](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml)

**Status / وضعیت:** The project is under development. The current main-branch game version is **0.43.0**. Main commit `0f20e499bf17966a9edb3639a4373205be048edd` passed its current Godot, GDScript, Python, artwork/map, and audio checks. An isolated **0.43.0-qa** Android APK was exported and signature-verified in [run 44710183868](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44710183868), artifact [14617302636](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44710183868/artifacts/14617302636). This is a debug-signed QA build, not a production release. The reusable wind controller is in `main`; the playable Alborz slice is still under review in [PR #36](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/36).

**وضعیت:** پروژه در حال توسعه است. نسخهٔ شاخهٔ اصلی **0.43.0** است. commit فعلی شاخهٔ `main` بررسی‌های Godot، GDScript، Python، تصاویر و نقشه‌ها و فایل‌های صوتی را با موفقیت گذرانده است. نسخهٔ آزمایشی **0.43.0-qa** اندروید در [اجرای 44710183868](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44710183868) ساخته و امضای آن بررسی شده است؛ [دریافت artifact شمارهٔ 14617302636](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44710183868/artifacts/14617302636). این خروجی با کلید موقت QA امضا شده و نسخهٔ انتشار رسمی نیست. موتور عمومی تندباد در `main` وجود دارد؛ مرحلهٔ قابل‌بازی البرز هنوز در [PR شمارهٔ ۳۶](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/36) در دست بازبینی است.

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
