# Release readiness | آمادگی انتشار

**Status checked: 18 November 2026 · Current game version: 0.40.0**

This file separates verified engineering status from items that still require the project owner's private files, evidence, device testing, or legal review. A passing CI run is not a release approval.

**وضعیت در ۱۸ نوامبر ۲۰۲۶ · نسخهٔ فعلی بازی: 0.40.0**

این سند وضعیت فنیِ تأییدشده را از مواردی که به فایل‌های خصوصی مالک، مدارک، آزمایش روی دستگاه یا بررسی حقوقی نیاز دارند جدا می‌کند. موفقیت CI به‌معنای تأیید انتشار نیست.

## Verified engineering status | وضعیت فنی تأییدشده

- Public source repository: `miladesmaeilpoor85-cell/Divslayer`, default branch `main`.
- Godot project main scene: `res://scenes/main.tscn`.
- The latest verified `main`-branch Godot CI run for commit `3fab88963aa924bc472ec48394e8f886f63c85ce` completed successfully:
  [GitHub Actions run 44285465485](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44285465485). The README records **1,145 checks across 30 test suites**. CI success confirms the configured headless checks, not full physical-device or store readiness.
- The CI workflow downloads Godot 4.7.2 and verifies its SHA-256 before importing the project and running the headless suite.
- Version 0.40.0 adds the Venom elite to poison-themed regions (Shadowfen, Damavand, and Zahhak's Cave), with regional selection, localization, scaling, aura, contact-poison, and poison-tick tests. The 0.40.0 pull request was merged after its CI check passed.
- The `main` branch history was rewritten on 18 November 2026. Anyone holding an older clone must create a fresh clone; do not merge or push old history back into `main`.

## Android release blockers | موارد لازم برای خروجی اندروید

- **Private export preset:** `export_presets.cfg` is present in `.gitignore` and is not tracked in the public tree. The public `project.godot` does not declare the production Android application ID/package identifier. Confirm the established package ID, version code, target/minimum SDK, architecture, permissions, and asset exclusions from the owner's private export settings. Do not invent a new package ID for an app that may already have been distributed.
- **Signing key:** The legacy test keystore/private key/certificate in an older private project archive are exposed and retired. The owner confirmed on 18 November 2026 that no APK signed with them was distributed to external testers or users, so no external install base requires that test key for updates. Never use or upload that material. Before the first external release, generate a **new production signing key locally**, keep two secure offline backups, and keep its password out of GitHub and chat.
- **Credential/cache follow-up:** A sample signing password appeared in an older public developer note. The current branches no longer contain that note's password, but GitHub's cached view from an old commit was previously observed and cache removal remains unconfirmed. The legacy test key is retired; never reuse its password for any production key or other service. A history rewrite does not invalidate old clones or caches.
- **QA build versus release:** A separate QA-only APK for `0.40.0-qa` was successfully built and signature-verified in [Android QA run 44284989984](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44284989984). It uses the separate package ID `com.example.divslayer.qa` and a temporary debug key; it is not a production build, signed with the owner's release key, or suitable for Google Play. No production AAB/release artifact is recorded.
  Follow the [Android device QA plan](ANDROID_DEVICE_QA.md) for boss-phase/pool regression, touch interaction, lifecycle, performance, and test-report steps.
- **Google Play target API:** As of 31 August 2026, new apps and app updates submitted to Google Play must target Android 16 / API level 36 or higher. The current QA workflow installs Android Platform 35 and Build Tools 35.0.1; verify and explicitly configure the *production target SDK* to API 36+ before Play submission. Do not infer target SDK compliance from a successful QA APK build. See [Google Play's official target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-en).
- **Play signing:** Decide whether to use Play App Signing and distinguish the private upload key from the app-signing key. If the game has already been distributed, preserve the established application ID and valid update-signing continuity. See [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).

## Asset rights audit | ممیزی حقوق دارایی‌ها

- **Music:** All 30 soundtrack tracks are present under `assets/audio/music/`; project records identify them as generated with Suno V6 through the Hoosha API and explicitly say that commercial-use status still needs verification. The repository does not contain independent evidence for each track. Suno's current help page says commercial-use rights apply to songs downloaded while on a paid plan; its Terms restrict permitted commercial exploitation to downloads through an approved Suno channel. The Hoosha API route is not independently verified. Retain receipts, generation/task IDs, dates, plan/account status, API authorization, download route, and dated terms in a private archive. Do not treat the current metadata claim as proof. See [Suno commercial rights](https://help.suno.com/en/articles/9601665) and [Suno Terms](https://suno.com/terms).
- **Ambience and SFX:** The metadata records 6 ambience items and 8 sound-effect entries as CC0. Verify their source files and matching license notices individually; do not extend these notices to the soundtrack or artwork.
- **Artwork:** `docs/ASSET_RIGHTS_REGISTER.csv` currently contains **371 image entries, all marked `UNVERIFIED`**. Record provenance (owner-created, AI-generated, or third-party), tool/source, creation date, applicable terms, and evidence for every file. Do not assume AI-generated images automatically have exclusive or commercially unrestricted rights.
- **Fonts and icons:** The repository contains separate license notices for its fonts and icon sets. Preserve those notices in any distribution and re-check them if assets are replaced.

## Technical/security audit | ممیزی فنی و امنیتی

See [TECHNICAL_SECURITY_AUDIT_0.40.0.md](TECHNICAL_SECURITY_AUDIT_0.40.0.md) for the detailed read-only review of the current `main` tree, CI workflows, QA build, source changes, and unresolved risks.

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
