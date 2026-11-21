# External Android QA — Divslayer 0.43.0-qa
# آزمون بیرونی اندروید — دیوکش 0.43.0-qa

**Baseline date / تاریخ مبنا:** 21 November 2026  
**Source commit / commit سورس:** `6fdc3c5176fbf87b07d59e1910fcdce26ebf4df2`  
**Status / وضعیت:** verified emulator QA artifact; physical-device tester results still required. This is not a production release.

## Download / دریافت

- Android QA workflow: [run 44906428530](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428530)
- Installable artifact: [Divslayer-Android-QA-APK — 14707913866](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428530/artifacts/14707913866)
- Artifact retention: **5 December 2026, 13:01:04 UTC**
- APK filename inside ZIP: `Divslayer-QA.apk`
- Package ID: `com.example.divslayer.qa`
- Version: `0.43.0-qa` (version code 1)
- Android manifest: minimum SDK 24; target SDK 36; ABIs ARM64-v8a, ARMv7, x86_64.
- APK SHA-256: `2fbddeaff8576041590ce6d9db4d9c67b9b42ed3dcdf29c492df59a1824aa751`

The APK was extracted from the GitHub Actions artifact and its SHA-256 was independently recomputed; it matches the checksum file included in the ZIP. The workflow's package/signature verification step passed. The artifact also includes APK badging metadata, emulator logcat, and a launch screenshot.

این APK از Artifact واقعی GitHub Actions استخراج و SHA-256 آن دوباره محاسبه شد؛ مقدار با فایل checksum داخل ZIP یکسان است. مرحلهٔ بررسی package و امضای APK در workflow موفق شده است. فایل ZIP علاوه بر APK شامل اطلاعات Manifest، لاگ شبیه‌ساز و تصویر اجرای برنامه است.

## Installation / نصب

1. Open the artifact link while signed in to GitHub; download the ZIP.
2. Extract the ZIP and locate `Divslayer-QA.apk`.
3. Open the APK on Android. If prompted, permit installation for the browser or file manager that opened it.
4. Launch **Divslayer QA** and confirm that the title/menu screen appears.
5. Keep any production app installed; the QA package is separate and uses `com.example.divslayer.qa`.

۱. لینک Artifact را باز کن و در صورت درخواست، وارد GitHub شو؛ سپس ZIP را دریافت کن.  
۲. فایل ZIP را استخراج و `Divslayer-QA.apk` را پیدا کن.  
۳. APK را در اندروید باز کن و در صورت درخواست، اجازهٔ نصب برای همان مرورگر یا فایل‌منیجر را فعال کن.  
۴. برنامهٔ **Divslayer QA** را اجرا و ظاهرشدن منوی اصلی بازی را بررسی کن.  
۵. برنامهٔ رسمی را حذف نکن؛ شناسهٔ بستهٔ QA جداست.

### Important signing/save warning / هشدار مهم امضا و ذخیره

This workflow generates a new temporary debug signing key for every run. A later QA APK may not install as an update over an earlier QA build. If Android reports a signature conflict, uninstall the older **Divslayer QA** app before installing this build. **Uninstalling deletes the old QA app's local save data.** Back up any important QA save first.

کلید Debug این workflow برای هر اجرا به‌صورت موقت و جدید ساخته می‌شود. ممکن است APK جدید روی نسخهٔ آزمایشی قبلی نصبِ به‌روزرسانی نشود. در صورت خطای تعارض امضا، نسخهٔ قبلی **Divslayer QA** را حذف کن؛ **این کار ذخیره‌های محلی همان برنامهٔ آزمایشی را پاک می‌کند.** پیش از حذف از ذخیرهٔ مهم پشتیبان بگیر.

This QA APK is not signed with the production key. It must not be used for production update continuity, production save migration, Google Play submission, or as proof of store acceptance. Do not share it as an official public release.

این APK با کلید انتشار رسمی امضا نشده و برای به‌روزرسانی نسخهٔ رسمی، مهاجرت ذخیرهٔ رسمی، ارسال به Google Play یا اثبات پذیرش فروشگاه مناسب نیست. آن را به‌عنوان نسخهٔ رسمی منتشرشده معرفی نکن.

## Verify the download / بررسی صحت فایل

Linux / Termux:

```sh
sha256sum Divslayer-QA.apk
```

Windows PowerShell:

```powershell
Get-FileHash .\Divslayer-QA.apk -Algorithm SHA256
```

Expected SHA-256:

```text
2fbddeaff8576041590ce6d9db4d9c67b9b42ed3dcdf29c492df59a1824aa751
```

## Physical-device test checklist / چک‌لیست آزمایش روی گوشی واقعی

Please record only tests you actually performed. Report failures with steps to reproduce; do not mark an untested item as passed.

- [ ] Clean installation succeeds.
- [ ] Game reaches the title/menu screen and starts a new game.
- [ ] Persian and English language selection displays correctly.
- [ ] Movement, light/heavy attack, dodge, block/parry, skills, and simultaneous touch work correctly.
- [ ] Ashkbus of Kushan's Turanian Arrowfall warning, dodge gaps, one-hit-per-volley protection, and stagger cancellation behave correctly.
- [ ] Anvil Warden's Forge Furrows behaves correctly.
- [ ] Pause/resume, Android Back, background/foreground, and lock/unlock work correctly.
- [ ] Save, fully close the app, relaunch, and confirm the QA save remains.
- [ ] Audio, music, and volume settings work.
- [ ] Check display cut-outs, touch target size, HUD overlap, and landscape layout.
- [ ] Play for 20–30 minutes; note approximate FPS, stutter, crashes, battery use, and heating.
- [ ] Test boss-phase changes and confirm old projectiles/pools do not keep damaging the player.

## Tester report / قالب گزارش

```text
Divslayer QA version: 0.43.0-qa
Source commit: 6fdc3c5176fbf87b07d59e1910fcdce26ebf4df2
Device model:
Android version:
RAM / storage (if known):
Display resolution (if known):
Install result:
Title/menu reached:
Language tested:
Movement / combat / touch:
Ashkbus Arrowfall:
Anvil Warden:
Boss phase cleanup:
Save / relaunch:
Audio:
Session duration:
Approximate FPS / frame-time (if measured):
Battery / thermal observations:
Crashes / bugs:
Steps to reproduce:
Screenshots / screen recording:
```

Share bug reports through [GitHub Issues](https://github.com/miladesmaeilpoor85-cell/Divslayer/issues). Include the APK version and device model, but do not publish passwords, signing files, private account data, or personal information.

گزارش باگ را در [GitHub Issues](https://github.com/miladesmaeilpoor85-cell/Divslayer/issues) ثبت کن. نسخهٔ APK و مدل دستگاه را بنویس؛ اما رمز عبور، فایل امضا، اطلاعات خصوصی حساب یا اطلاعات شخصی را در Issue عمومی قرار نده.

## What the automated run proves / نتیجهٔ تست خودکار

- Godot 4.7.2 CI [run 44906428789](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428789) passed all four headless test shards.
- Android QA [run 44906428530](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44906428530) completed successfully on `main` commit `6fdc3c5176fbf87b07d59e1910fcdce26ebf4df2`.
- The workflow exported and package/signature-checked the APK, installed/launched it in the Android emulator, detected `OnGodotSetupCompleted`, confirmed the game Activity remained in the foreground, scanned logs for fatal/script errors and ANR, and uploaded the installable artifact.
- The captured emulator screenshot shows the **Godot splash screen**, not the title menu or gameplay. A tester must confirm those screens on a physical device.
- This does not establish compatibility with every Android device, completion of the gameplay checklist, production signing, Google Play approval, or commercial asset clearance.

آزمون Godot 4.7.2 در اجرای بالا هر چهار بخش headless را گذرانده است. اجرای Android QA نیز ساخت APK، بررسی package و امضا، نصب و اجرای شبیه‌ساز، ثبت نشانگر راه‌اندازی Godot، باقی‌ماندن Activity در پیش‌زمینه و بررسی لاگ‌های خطا را با موفقیت گذرانده است. تصویر ذخیره‌شده صفحهٔ آغاز Godot است، نه منوی اصلی یا گیم‌پلی؛ تأیید این بخش‌ها به آزمایش واقعی روی گوشی نیاز دارد.

## Physical testing still outstanding / آزمایش فیزیکی باقی‌مانده

The previous device reports in `ANDROID_DEVICE_QA.md` refer to older QA versions and must not be counted as tests of this 0.43.0-qa artifact. Record a fresh report for this build before treating external QA as complete.

گزارش‌های قدیمی‌تر ثبت‌شده در `ANDROID_DEVICE_QA.md` مربوط به نسخه‌های قبلی QA هستند و نباید به‌عنوان آزمایش این APK جدید محسوب شوند. پیش از تکمیل مرحلهٔ QA بیرونی، گزارش تازه‌ای برای همین نسخه ثبت کن.
