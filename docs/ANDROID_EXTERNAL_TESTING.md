# External Android QA — Divslayer 0.43.0-qa
# آزمون بیرونی اندروید — دیوکش 0.43.0-qa

**Baseline date / تاریخ مبنا:** 18 November 2026  
**Status / وضعیت:** installable QA build; not a production release.

## Download the baseline APK / دریافت APK مبنا

- Repository / مخزن: [miladesmaeilpoor85-cell/Divslayer](https://github.com/miladesmaeilpoor85-cell/Divslayer)
- Source commit / commit سورس: `5a024af9b659cec3f1c73fd610d660cefdaa78c3`
- Android QA workflow / اجرای ساخت: [run 44323688690](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44323688690)
- Artifact / فایل فشرده: [Divslayer-Android-QA-APK — artifact 14435797831](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44323688690/artifacts/14435797831)
- Artifact retention / مهلت نگهداری: **2 December 2026** (GitHub Actions retention).
- APK filename / نام APK: `Divslayer-QA.apk`
- Package / شناسه بسته: `com.example.divslayer.qa`
- Version / نسخه: `0.43.0-qa` (version code 1)
- Android compatibility / سازگاری: minimum SDK 24; target SDK 36; ARMv7 and ARM64.
- APK SHA-256: `9542ce739b0acae5a45fa0e54d4f02859ae763da0a698353d0ec0d47bc33d885`

The workflow verified the APK with Android `apksigner` (signature schemes v2 and v3). The artifact ZIP contains the APK, its SHA-256 file, and APK manifest/badging details.

این خروجی برای نصب و آزمون بازی روی گوشی اندرویدی ساخته شده است. امضای APK با ابزار رسمی Android بررسی شده؛ فایل فشرده شامل APK، فایل checksum و اطلاعات Manifest است.

## Installation / نصب

1. Open the artifact link above while signed in to GitHub if GitHub requests authentication, then download the ZIP.
2. Extract the ZIP and locate `Divslayer-QA.apk`.
3. On Android, open the APK and approve installation for the browser/file manager used to open it, if Android asks.
4. Launch **Divslayer QA**. It installs as a separate QA app; it does not replace an app whose package ID is different.

۱. پیوند Artifact بالا را باز کن و در صورت درخواست GitHub وارد حساب شو؛ سپس فایل ZIP را دریافت کن.  
۲. ZIP را استخراج کن و فایل `Divslayer-QA.apk` را پیدا کن.  
۳. APK را در اندروید باز کن و در صورت درخواست سیستم، اجازه نصب برای همان مرورگر یا فایل‌منیجر را بده.  
۴. برنامهٔ **Divslayer QA** را اجرا کن. این نسخه جدا از برنامه‌ای با شناسه بسته متفاوت نصب می‌شود.

### Important signing and save warning / هشدار مهم درباره امضا و ذخیره

This QA workflow generates a new temporary debug signing key for each run. A later QA artifact may not install as an update over a previous QA build. Before installing a newer QA artifact, uninstall the old **Divslayer QA** app first. **Uninstalling deletes that QA app's local save data.** Back up anything important before uninstalling.

The QA key and QA package are not the production signing identity. Do not use this APK to verify production updates, production save migration, Google Play acceptance, or release-signature continuity. Do not confuse this artifact with an official public release.

این گردش‌کار برای هر اجرا یک کلید موقت Debug جدید می‌سازد. بنابراین ممکن است APK جدید روی نسخه QA قبلی به‌روزرسانی نشود. پیش از نصب خروجی جدید، نسخه قبلی **Divslayer QA** را حذف کن؛ **حذف برنامه، ذخیره‌های محلی همان نسخه QA را پاک می‌کند.** اگر اطلاعات مهمی داری، پیش از حذف پشتیبان بگیر.

این کلید و شناسه بسته متعلق به نسخه رسمی نیستند. این APK برای بررسی به‌روزرسانی نسخه رسمی، مهاجرت ذخیره‌های رسمی، تأیید Google Play یا تداوم امضای نسخه انتشار مناسب نیست.

## Verify the download / بررسی صحت فایل

On a computer with `sha256sum`:

```sh
sha256sum Divslayer-QA.apk
```

In Termux on Android, the same command is available after installing the appropriate package. On Windows PowerShell:

```powershell
Get-FileHash .\Divslayer-QA.apk -Algorithm SHA256
```

The result must equal:

```text
9542ce739b0acae5a45fa0e54d4f02859ae763da0a698353d0ec0d47bc33d885
```

## Test checklist / چک‌لیست آزمایش

Please test what you can and report both passes and failures. Do not mark a test as passed if it was not performed.

- [ ] APK installs successfully.
- [ ] Game launches and reaches the title/menu screen.
- [ ] Start a new game and enter gameplay.
- [ ] Persian and English language selection displays correctly.
- [ ] Movement, attack, dodge, block/parry, skills, and touch controls respond correctly.
- [ ] Ashkbus of Kushan's Turanian Arrowfall telegraph appears; gaps can be used to dodge.
- [ ] The Arrowfall volley does not hit more than once; staggering Ashkbus during the warning cancels the move.
- [ ] Anvil Warden's Forge Furrows move still behaves correctly.
- [ ] Pause/resume and Android Back behavior work as expected.
- [ ] Save, fully close the app, relaunch, and verify the save is still present.
- [ ] Audio, music, and volume settings work.
- [ ] Play for 20–30 minutes and note crashes, freezing, stutter, battery/thermal behavior, and approximate FPS.
- [ ] Record screen-size/layout issues, cut-outs, or controls hidden by system UI.

### Tester report template / قالب گزارش آزمایش

```text
Divslayer QA version: 0.43.0-qa
Source commit: 5a024af9b659cec3f1c73fd610d660cefdaa78c3
Device model:
Android version:
RAM / storage (if known):
Display resolution (if known):
Install result:
Language tested:
Gameplay / controls:
Ashkbus Arrowfall:
Anvil Warden:
Save / relaunch:
Audio:
Session duration:
Approximate FPS (if known):
Crashes / bugs:
Steps to reproduce:
Screenshots or screen recording:
```

Share bug reports through [GitHub Issues](https://github.com/miladesmaeilpoor85-cell/Divslayer/issues). Include the APK version and device details, but do not include passwords, private files, account information, or personal data in public issues.

گزارش باگ را از طریق [GitHub Issues](https://github.com/miladesmaeilpoor85-cell/Divslayer/issues) ارسال کن. نسخه APK و مشخصات دستگاه را بنویس، اما رمز عبور، فایل خصوصی، اطلاعات حساب یا داده شخصی را در Issue عمومی قرار نده.

## What this baseline proves — and does not prove / این نسخه چه چیزی را ثابت می‌کند؟

The matching main-branch Godot CI run [44323688776](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44323688776) passed **1,165 checks across 32 test suites** plus the autotest. The Android QA run [44323688690](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44323688690) completed successfully, exported the APK, checked the package metadata, and verified the APK signature.

These are automated build and test results. They do not establish compatibility with every Android device, complete gameplay acceptance, production signing, store approval, commercial asset clearance, or legal readiness. The game is still under development.

اجرای متناظر CI شاخه اصلی، شماره 44323688776، شامل **۱٬۱۶۵ بررسی در ۳۲ مجموعه تست** به‌علاوه autotest بود و موفق شد. اجرای ساخت اندروید شماره 44323688690 نیز APK را ساخت، اطلاعات بسته را بررسی کرد و امضای APK را تأیید کرد.

این نتایج، موفقیت ساخت و تست خودکار را نشان می‌دهند؛ اما سازگاری با همه گوشی‌ها، تأیید کامل گیم‌پلی، امضای تولیدی، تأیید فروشگاه، مجوز تجاری دارایی‌ها یا آمادگی حقوقی را ثابت نمی‌کنند. بازی همچنان در حال توسعه است.
