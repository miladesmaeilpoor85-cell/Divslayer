# Divslayer | دیوکش

A Persian-mythology-inspired action RPG made with Godot.

یک بازی اکشن نقش‌آفرینی با الهام از شاهنامه و اسطوره‌های ایرانی، ساخته‌شده با Godot.

[![Godot CI](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml/badge.svg?branch=main)](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/workflows/godot-ci.yml)

**Status / وضعیت:** The project is under development. Current game version: **0.43.0**. The latest verified Godot 4.7.2 CI run ([#44301894793](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44301894793)) passed **1,165 checks across 32 test suites**, plus the autotest, with zero failures. The Android QA build **0.43.0-qa** was exported and its APK signature verified in [run #44301894537](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44301894537) ([artifact](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44301894537/artifacts/14426177656)). PR [#15](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/15) added Ashkbus's Turanian arrowfall attack. These are test/QA results, not a production release or store approval.

**وضعیت:** پروژه هنوز در حال توسعه است. نسخهٔ فعلی بازی **0.43.0** است. اجرای تأییدشدهٔ Godot 4.7.2 با شمارهٔ 44301894793 شامل **۱٬۱۶۵ بررسی در ۳۲ مجموعهٔ تست** به‌علاوهٔ autotest بود و هیچ شکستی نداشت. نسخهٔ آزمایشی اندروید **0.43.0-qa** نیز در اجرای 44301894537 ساخته و امضای APK آن تأیید شد ([دریافت artifact](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44301894537/artifacts/14426177656)). درخواست ادغام شمارهٔ [۱۵](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/15) حملهٔ اختصاصی باران تیرهای تورانی اشکبوس را اضافه کرد. این‌ها نتایج آزمون و خروجی QA هستند، نه انتشار نهایی یا تأیید فروشگاه.


## Repository history / تاریخچه مخزن
On 18 November 2026, the `main` branch history was rewritten to remove an old sample signing password from historical developer notes. Anyone with a clone created before that date should make a fresh clone before contributing; do not merge or push the old clone's history back into `main`. Back up any uncommitted personal work separately first.

در ۱۸ نوامبر ۲۰۲۶ تاریخچه شاخهٔ `main` برای حذف یک گذرواژهٔ نمونه از یادداشت‌های قدیمی بازنویسی شد. اگر پیش از این تاریخ مخزن را clone کرده‌اید، پیش از هر مشارکت clone تازه بگیرید؛ تاریخچهٔ clone قدیمی را دوباره با `main` ادغام یا push نکنید. ابتدا از تغییرات شخصیِ commit‌نشده جداگانه پشتیبان تهیه کنید.

See [release readiness](docs/RELEASE_READINESS.md) for the current blockers before Android or commercial release.

See the [asset pipeline](docs/ASSET_PIPELINE.md) for the automated image/audio integrity checks and artwork rights-register workflow.

See the [multi-tool production pipeline](docs/MULTITOOL_PIPELINE.md) for cloud-based GDScript/Python analysis, FFmpeg audio decoding, full image inspection, and automated map-layout previews.

See the [creative applications workflow](docs/CREATIVE_TOOLS.md) for Krita, Audacity, LMMS, and Blender cloud smoke tests and source-project handling.

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

See the [animation production pipeline](docs/ANIMATION_PIPELINE.md) for the first multi-frame warrior attack, its source sheet, builder, and QA workflow.
