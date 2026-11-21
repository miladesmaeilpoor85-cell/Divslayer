# Release readiness | آمادگی انتشار

**Status checked: 21 November 2026 · Main-branch baseline: 0.43.0 · Latest recorded main commit: 7decddb22cf4ab4b55da9347e7d6a82a5e72eb6b**

This file separates verified engineering status from items that still require the project owner's private files, evidence, device testing, or legal review. A passing CI run is not a release approval.

**وضعیت در ۱۸ نوامبر ۲۰۲۶ · نسخهٔ فعلی بازی: 0.43.0**

این سند وضعیت فنیِ تأییدشده را از مواردی که به فایل‌های خصوصی مالک، مدارک، آزمایش روی دستگاه یا بررسی حقوقی نیاز دارند جدا می‌کند. موفقیت CI به‌معنای تأیید انتشار نیست.

## Verified engineering status | وضعیت فنی تأییدشده

- Public source repository: `miladesmaeilpoor85-cell/Divslayer`, default branch `main`.
- Godot project main scene: `res://scenes/main.tscn`.
- The latest recorded main-branch Godot 4.7.2 validation completed successfully in [Godot CI run 457](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44904064171): all four headless test shards passed. The latest [multi-tool run 348](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44904064227) also passed GDScript lint, Python/Ruff lint, artwork decode/map previews, and audio decode/metadata checks. These are automated checks, not a complete physical-device or store-release pass.
- The corrected Android QA workflow passed in [run 202](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44905519384) on the current main code base via PR #56. The 0.43.0 QA APK was exported, package-checked and signature-verified; installed and launched in the Android emulator; logged `OnGodotSetupCompleted`; remained in the foreground; passed the fatal/script-error scan; and produced a launch screenshot showing the Divslayer title menu. Its normal installable artifact is [14707328088](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44905519384/artifacts/14707328088), expires 5 December 2026. The APK SHA-256 is `1089b7fc3d07057b001af6c4049137f9245ba6fc348d88beab0088b8c3e9bf3b`. PR #56 remains open for review/merge; the workflow fix has not yet been merged to main. This QA package is debug-signed and is not a production release.
- The QA build added Ashkbus of Kushan's exclusive Turanian Arrowfall attack: three separated warning zones, falling arrows, dodgeable gaps, one-hit-per-volley protection, and cancellation when Ashkbus is staggered during the warning.
- The CI workflow downloads Godot 4.7.2 and verifies its SHA-256 before importing the project and running the headless suite. The asset pipeline in [ASSET_PIPELINE.md](ASSET_PIPELINE.md) adds dependency-free artwork/audio integrity checks and exact coverage validation against the artwork rights register.
- The production Android export preset, production package identity, and production signing configuration remain private and must be verified separately. QA manifest values must not be treated as proof of production release readiness.
- The `main` branch history was rewritten on 18 November 2026. Anyone holding an older clone must create a fresh clone; do not merge or push old history back into `main`.

## Merged Chapter IV work | فصل چهارم ادغام‌شده

- PR #38 integrated the coordinated weather, dodge, Thornwood, and Alborz vertical-slice work into `main`; PR #37 subsequently integrated the High Eyrie side-area and three-phase Gale Warden encounter. See [PR #38](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/38) and [PR #37](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/37).
- These integrations do not mean every environment asset is final. Alborz still has temporary/reused ground and character/prop art; the remaining dedicated art and its rights evidence are release tasks.
- Main now has multi-frame Starter attacks for Warrior and Rogue. Mage Starter and Paladin Starter still need genuine attack poses; the other 30 directional hero attack clips are one-pose clips. See [the animation pipeline audit](ANIMATION_PIPELINE.md).


## Latest animation readiness | آمادگی انیمیشن

The production manifest has 36 directional hero attack clips across 12 class/gear appearances. Warrior Starter and Rogue Starter have three four-frame directional clips each (six multi-frame clips total); the other 30 clips remain single-pose attacks. The runtime/asset import path supports reviewed attack atlases and contact-frame timing, but this is not evidence that all four classes or all gear tiers have complete combat animation. Commercial-use evidence for the currently registered attack artwork remains unverified.


## Android release blockers | موارد لازم برای خروجی اندروید

- **Private export preset:** `export_presets.cfg` is present in `.gitignore` and is not tracked in the public tree. The public `project.godot` does not declare the production Android application ID/package identifier. Confirm the established package ID, version code, target/minimum SDK, architecture, permissions, and asset exclusions from the owner's private export settings. Do not invent a new package ID for an app that may already have been distributed.
- **Signing key:** The legacy test keystore/private key/certificate in an older private project archive are exposed and retired. The owner confirmed on 18 November 2026 that no APK signed with them was distributed to external testers or users, so no external install base requires that test key for updates. Never use or upload that material. Before the first external release, generate a **new production signing key locally**, keep two secure offline backups, and keep its password out of GitHub and chat.
- **Credential/cache follow-up:** A sample signing password appeared in an older public developer note. The current branches no longer contain that note's password, but GitHub's cached view from an old commit was previously observed and cache removal remains unconfirmed. The legacy test key is retired; never reuse its password for any production key or other service. A history rewrite does not invalidate old clones or caches.
- **QA build versus release:** The latest recorded QA-only APK is `0.43.0-qa`, package `com.example.divslayer.qa`, artifact [14707328088](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44905519384/artifacts/14707328088), from run 202. It was successfully installed/launched in the emulator and its SHA-256 is `1089b7fc3d07057b001af6c4049137f9245ba6fc348d88beab0088b8c3e9bf3b`. It uses a temporary debug key; it is not signed with the owner's production key and is not a production build or Google Play release. No production AAB/release artifact is recorded.
  Follow the [Android device QA plan](ANDROID_DEVICE_QA.md) for boss-phase/pool regression, touch interaction, lifecycle, performance, and test-report steps.
- **Google Play target API:** As of 31 August 2026, new apps and app updates submitted to Google Play must target Android 16 / API level 36 or higher. The 0.43.0 QA APK manifest was verified at target SDK 36, but its export preset is QA-only. The *production* target SDK remains unverified until the owner's private production export configuration is reviewed. See [Google Play's official target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-en).
- **Play signing:** Decide whether to use Play App Signing and distinguish the private upload key from the app-signing key. If the game has already been distributed, preserve the established application ID and valid update-signing continuity. See [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).

## Asset rights audit | ممیزی حقوق دارایی‌ها

- **Music:** All 30 soundtrack tracks are present under `assets/audio/music/`; project records identify them as generated with Suno V6 through the Hoosha API and explicitly say that commercial-use status still needs verification. The credits now track `UNVERIFIED` status and a per-track private-proof reference, rather than implying a blanket commercial-use grant. The repository does not contain independent evidence for each track. Suno's current help page says commercial-use rights apply to songs downloaded while on a paid plan; its Terms restrict permitted commercial exploitation to downloads through an approved Suno channel. The Hoosha API route is not independently verified. Retain receipts, generation/task IDs, dates, plan/account status, API authorization, download route, and dated terms in a private archive. Do not treat the current metadata claim as proof. See [Suno commercial rights](https://help.suno.com/en/articles/9601665) and [Suno Terms](https://suno.com/terms).
- **Ambience and SFX:** The metadata records 6 ambience items and 8 sound-effect entries as CC0. Verify their source files and matching license notices individually; do not extend these notices to the soundtrack or artwork.
- **Artwork:** `docs/ASSET_RIGHTS_REGISTER.csv` contains **371 image entries, all marked `UNVERIFIED`** in the inspected baseline. The CI release-evidence report counts any entry without both `VERIFIED` status and a private evidence reference as a blocker. Record provenance (owner-created, AI-generated, or third-party), tool/source, creation date, applicable terms, and evidence for every file. Do not assume AI-generated images automatically have exclusive or commercially unrestricted rights.
- **Fonts and icons:** The repository contains separate license notices for its fonts and icon sets. Preserve those notices in any distribution and re-check them if assets are replaced.

## Technical/security audit | ممیزی فنی و امنیتی

See [TECHNICAL_SECURITY_AUDIT_0.40.0.md](TECHNICAL_SECURITY_AUDIT_0.40.0.md) for a historical read-only review of the 0.40.0 tree; it is not a fresh audit of the current 0.43.0 code.

## Legal and community status | وضعیت حقوقی و مشارکت

- The project is **source-available, not open source** under its current provisional proprietary notice.
- The current `LICENSE` is provisional and has not been reviewed as a final agreement.
- `CLA.md` is a draft only. Obtain qualified legal review in Germany and other relevant markets before accepting code, art, audio, translation, or other contributions under commercial-use terms.
- Until the contributor process is reviewed and explicitly published, accept bug reports and feature discussions through Issues only; do not treat a pull request as accepted or promise payment/rights terms.

## Historical cache follow-up | پیگیری cache تاریخچهٔ قدیمی

The current `main` branch no longer contains the old sample password in its rewritten `DEV_NOTES.md` history. However, GitHub still served the original file when it was requested directly through an old commit SHA. This means server-side cache removal has **not** been confirmed.

GitHub Support's documented policy says it will assist with cached-view and unreachable-object removal only for sensitive data where the risk cannot be mitigated by rotating the affected credential. Rotate a real affected credential first, if applicable, and then submit a private request through [GitHub Support](https://support.github.com/contact). Provide the repository name, affected PR count (0 known), the original affected commit, and an honest explanation that this history was reconstructed through the GitHub Git Data API rather than `git-filter-repo`; therefore no `git-filter-repo` First Changed Commit report exists. Support may decline if the data is not considered sensitive or rotation is sufficient.

## Fresh clone after the history rewrite | دریافت clone تازه پس از بازنویسی تاریخچه

In Termux, create a new directory instead of trying to push an older clone:

```sh
cd ~/storage/downloads
git clone https://github.com/miladesmaeilpoor85-cell/Divslayer.git Divslayer-clean
cd Divslayer-clean
git status
git log -1 --oneline
```

If the directory already exists, choose a different new folder name. Back up uncommitted personal changes from the old folder before discarding it. Never push or merge the old clone's pre-rewrite history into the new `main`.

---

**Release decision:** Not ready for an Android store release or commercial distribution until the production application identity/signing setup is verified, the production target SDK is API 36+, any affected credential is rotated if it was reused, the 371 image records and all soundtrack rights are documented, legal terms are reviewed, privacy statements are verified, and signed device testing is complete.
