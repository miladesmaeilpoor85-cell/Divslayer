# Technical and Security Audit — Divslayer 0.40.0
# ممیزی فنی و امنیتی — دیوکش 0.40.0

**Review date:** 18 November 2026  
**Reviewed branch / commit:** `main` — `3fab88963aa924bc472ec48394e8f886f63c85ce`  
**Review type:** Read-only repository and workflow inspection; no source-code or asset deletion was performed.

## Executive summary / خلاصه

Divslayer 0.40.0 is a substantial, actively maintained Godot project. The current main-branch Godot CI run completed successfully, and a separate 0.40.0 QA APK was exported and signature-verified. The source tree includes game scripts, scenes, art, audio, data, documentation, and automated tests.

**This is not a release approval.** The most important remaining blockers are asset rights evidence (371 image entries remain unverified and the 30-track Suno/Hoosha soundtrack has unresolved channel/terms evidence), production Android identity/signing configuration, Google Play's API 36 target requirement, and final legal/privacy review.

دیوکش نسخه 0.40.0 پروژه‌ای فعال و دارای پیشرفت فنی قابل توجه است. CI شاخه اصلی موفق شده و APK آزمایشی 0.40.0 نیز ساخته و امضای آن بررسی شده است. بااین‌حال این ممیزی تأیید انتشار نیست. مهم‌ترین موانع باقی‌مانده، مدارک حقوق دارایی‌ها، تنظیمات خصوصی انتشار اندروید، الزام API 36 گوگل‌پلی و بررسی نهایی حقوقی و حریم خصوصی هستند.

## 1. Scope and evidence / دامنه و شواهد

Reviewed:
- Repository metadata and the recursive `main` tree (1,434 entries).
- `project.godot`, the current game version constant, selected game scripts, the test runner, and the Godot/Android GitHub Actions workflows.
- The Venom elite PR and the boss transient-effect cleanup changes/tests.
- `README.md`, `CHANGELOG.md`, `DEV_NOTES.md`, `LICENSE`, `CLA.md`, `docs/RELEASE_READINESS.md`, `docs/ANDROID_DEVICE_QA.md`, `docs/ASSET_RIGHTS_REGISTER.csv`, and audio credits.
- Latest main CI run and 0.40.0 QA APK workflow result.

This review did not execute the project locally, inspect the APK binary independently, perform a full binary/content secret scan, verify every third-party license, or conduct new physical-device tests. CI results cited below are GitHub Actions results, not tests run by this audit.

## 2. Engineering review / بازبینی فنی

### Positive findings
- Current source version is `0.40.0`; `project.godot` declares Godot 4.7 / GL Compatibility and `res://scenes/main.tscn` as the main scene.
- The latest main-branch Godot CI run [#44285465485](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44285465485) completed successfully on commit `3fab889`. The README reports 1,145 checks across 30 suites.
- CI verifies the downloaded Godot 4.7.2 archive by SHA-256, imports/parses the project headlessly, compiles Python tools, validates audio metadata shape, and runs `tools/run_all_tests.sh ci`.
- Version 0.40.0 adds the Venom elite only to Shadowfen, Damavand, and Zahhak's Cave. Tests cover regional selection, English/Persian labels, scaling, aura, contact poison, and poison ticks.
- Boss cleanup now clears telegraphs, waves, lobs, projectiles, damaging pools, and delayed actions. Regression tests cover idempotency and boss phase transitions/death. The corresponding PRs were merged after successful CI.

### Engineering gaps
- The CI workflow does not visibly run a GDScript linter, dedicated dependency/security scanner, or automated asset-license audit. Godot parse/import and gameplay tests do not replace those checks.
- The custom `tools/apk_sign_v2.py` constructs an APK Signing Block itself. The current QA workflow does **not** use this script; it uses Godot's Android export and verifies the resulting APK with Android's `apksigner`. Do not make the custom signer part of production release until it has independent interoperability tests and a documented maintenance owner. Prefer the official Android/Godot signing toolchain.
- The Android QA workflow produces a QA app, not a release candidate.

## 3. Security review / بازبینی امنیتی

### Current-tree checks
- The reviewed `main` tree contains no obvious `signing/` directory, PEM/P12/JKS/keystore files, APK/AAB release binaries, or tracked `export_presets.cfg`.
- The current `.gitignore` already excludes `export_presets.cfg`, the `signing/` directory, common key/certificate formats, `.env*`, and build/export output directories. This is correct; no edit to `.gitignore` was necessary.
- The visible workflows declare `contents: read`; the Android QA workflow creates a temporary debug keystore inside the ephemeral runner and uses the QA-only package `com.example.divslayer.qa`. It does not load the owner's production key or private export preset.
- Limited GitHub code-search checks for several common token/private-key markers returned no matches. This is not a comprehensive scan of all Git objects, binary payloads, caches, or historical commits.

### Historical credential follow-up — high priority
The repository's current README and release-readiness notes disclose that a sample signing password appeared in an old public developer note. The history was rewritten, but the project notes say GitHub still served the old file when queried through an old commit SHA. Therefore cache removal is not confirmed. If that sample password was ever reused for a real keystore/key, treat it as compromised and rotate the affected password locally while preserving the valid key pair. A history rewrite does not rotate credentials and does not invalidate old clones or cached copies. Follow the private GitHub Support procedure already recorded in `docs/RELEASE_READINESS.md`.

## 4. Asset rights / حقوق دارایی‌ها

### Artwork — release blocker
`docs/ASSET_RIGHTS_REGISTER.csv` contains 371 image records and all 371 are currently marked `UNVERIFIED`. No claim of commercial clearance or permission to redistribute these images should be made until each entry has evidence for creator/source, generation tool, creation date, applicable terms, and any third-party inputs. AI-generated does not automatically mean exclusive, copyrightable, or commercially unrestricted.

### Music — release blocker
There are 30 soundtrack files in `assets/audio/music/`. Project credits identify them as generated with Suno V6 through the Hoosha API and explicitly retain a commercial-use verification warning. The repo does not include per-track receipts, generation/task IDs, plan status, or proof that the third-party API/download route met the provider's approved-channel requirements.

Suno's current published help page says commercial-use rights apply to songs downloaded while subscribed to a paid plan. Its Terms state that permitted commercial exploitation depends on obtaining a permitted download through an approved Suno channel. This audit cannot verify the Hoosha API route or the terms applicable to each generation date. Keep the tracks out of a commercial release until that evidence is checked. References:
- [Suno — commercial rights with a paid subscription](https://help.suno.com/en/articles/9601665)
- [Suno — Terms of Service](https://suno.com/terms)

### Other audio, fonts, and icons
The project metadata identifies 6 ambience items and 8 SFX entries as CC0, with attribution/source records and some bundled license notices. Verify each source record and its exact asset mapping before external commercial distribution. Preserve the bundled OFL font notices and the icon-set license notices.

## 5. Android release readiness / آمادگی انتشار اندروید

- The successful [0.40.0 Android QA run #44284989984](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44284989984) generated an installable QA artifact and verified its APK signature. The artifact uses `com.example.divslayer.qa`, version `0.40.0-qa`, and an ephemeral debug key; it expires on 2 December 2026. It is not a production APK/AAB and is not suitable for Google Play.
- The QA workflow installs Android Platform 35 and Build Tools 35.0.1. This is a QA toolchain detail, not proof of the release target SDK.
- Google Play's policy states that, from 31 August 2026, new apps and app updates must target Android 16 / API level 36 or higher. Explicitly configure and verify the **production target SDK** at API 36+ before submission: [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-en).
- The production `export_presets.cfg`, application ID/package name, version code, SDK configuration, permissions, and release keystore are intentionally private and are not in the repository. Confirm the existing production app identity before building. Never invent a new package ID or change signing identity if existing installs must be updated.
- Decide on Google Play App Signing and keep the upload key separate from the app-signing key. Follow the official [Play App Signing guide](https://support.google.com/googleplay/android-developer/answer/9842756).
- No production signed AAB/release artifact, production update test, or Play Console submission is evidenced by the current workflow results.

## 6. Privacy and legal / حریم خصوصی و حقوقی

- `docs/privacy_policy.md` is a draft with placeholders for the last-updated date and developer contact. It makes categorical claims about no internet connection, tracking, ads, or data collection. Verify those statements against the final exported Android manifest, permissions, plugins, and all runtime code before publication; then fill in a real contact channel and publish a dated policy.
- `LICENSE` is marked provisional; `CLA.md` is marked draft and not approved for signature/enforcement. The README correctly says the project is source-available, not open source, and currently asks people not to submit code/art/audio PRs for inclusion. Keep that restriction until reviewed contribution terms and explicit acceptance workflow are ready.
- Obtain qualified legal review for the proprietary notice, contributor terms, AI-generated artwork, music, fonts, and third-party assets in Germany and other relevant markets.

## 7. Recommended order of work / ترتیب پیشنهادی

1. **Resolve historical credential risk:** determine whether the exposed sample password was reused; rotate it if so; complete the documented GitHub Support cache-removal request if still applicable.
2. **Complete asset rights evidence:** verify all 371 image records and each of the 30 Suno/Hoosha tracks; decide whether any unverified files must be temporarily removed from public distribution or replaced.
3. **Lock production Android identity:** confirm package ID, version code, signing key continuity, and backup procedure without uploading private files.
4. **Upgrade the production Android target to API 36+:** align SDK/build tools/templates, export an AAB, and verify manifest, target SDK, signature, package, and permissions.
5. **Finish QA and privacy/legal review:** test install/update/save migration on physical devices, finalize privacy statements and contact details, and review LICENSE/CLA before accepting contributions.
6. **Harden CI:** add a GDScript lint step and a repeatable secret/dependency/asset-license check; consider pinning GitHub Actions to full commit SHAs.

## Conclusion / نتیجه

**Divslayer 0.40.0 has a successful automated engineering baseline and a successful isolated QA APK build, but it is not ready for commercial distribution or a Google Play release.** The immediate blockers are asset-rights evidence, production signing/application identity, API 36 target compliance, the possible historical credential reuse, and final legal/privacy review.

**دیوکش 0.40.0 از نظر CI و ساخت APK آزمایشی وضعیت امیدوارکننده‌ای دارد، اما برای انتشار تجاری یا Google Play آماده نیست.** موانع اصلی عبارت‌اند از مدارک حقوق دارایی‌ها، هویت و امضای رسمی اندروید، رعایت API 36، احتمال استفاده مجدد از گذرواژه تاریخی و نهایی‌سازی بررسی حقوقی و حریم خصوصی.
