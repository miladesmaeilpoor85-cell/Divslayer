# Release readiness | آمادگی انتشار

**Status checked: 18 November 2026 · Current game version: 0.39.0**

This file separates verified engineering status from items that still require the project owner's private files, evidence, device testing, or legal review. A passing CI run is not a release approval.

**وضعیت در ۱۸ نوامبر ۲۰۲۶ · نسخهٔ فعلی بازی: 0.39.0**

این سند وضعیت فنیِ تأییدشده را از مواردی که به فایل‌های خصوصی مالک، مدارک، آزمایش روی دستگاه یا بررسی حقوقی نیاز دارند جدا می‌کند. موفقیت CI به‌معنای تأیید انتشار نیست.

## Verified engineering status | وضعیت فنی تأییدشده

- Public source repository: `miladesmaeilpoor85-cell/Divslayer`, default branch `main`.
- Godot project main scene: `res://scenes/main.tscn`.
- The latest verified full CI run before this checklist was added passed **1,115 checks across 28 test suites**, with no failures:
  [GitHub Actions run 44255186665](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44255186665).
- The CI workflow downloads Godot 4.7.2 and verifies its SHA-256 before importing the project and running the headless suite.
- Version 0.39.0 includes regional enemy signature attacks. A later history rewrite preserved the tested file tree and all current source files.
- The `main` branch history was rewritten on 18 November 2026. Anyone holding an older clone must create a fresh clone; do not merge or push old history back into `main`.

## Android release blockers | موارد لازم برای خروجی اندروید

- **Private export preset:** `export_presets.cfg` is intentionally git-ignored. The public `project.godot` does not declare an Android application ID/package identifier. Confirm the established package ID, version code, target/minimum SDK, architecture, permissions, and asset exclusions using the owner's private export settings. Do not invent a new package ID for an app that may already have been distributed.
- **Signing key:** The Android keystore and certificates are intentionally excluded from the public repository. Keep the original release key and a private backup. Never upload `emberiron.p12`, PEM files, certificates, passwords, or signing aliases to GitHub or chat.
- **Credential rotation:** A sample signing password appeared in an old public developer note. If that value was ever used for the real keystore or key, treat the affected password as exposed and rotate it locally while preserving the same key pair. A history rewrite does not rotate a password and cannot erase old clones or caches.
- **Build and device tests:** No release APK/AAB or GitHub Release has been published from the current CI workflow. Configure the private Android export environment and run a signed export, install/update tests on real Android devices, and verify app identity, save migration, permissions, performance, and store requirements before release.
  Follow the [Android device QA plan](ANDROID_DEVICE_QA.md) for the boss-phase/pool regression, touch interaction, lifecycle, performance, and test-report matrix.

## Asset rights audit | ممیزی حقوق دارایی‌ها

- **Music:** Project records describe 30 soundtrack tracks as generated with Suno V6 through the Hoosha API. The repository does not contain sufficient independent evidence to confirm commercial-use rights for every track. Retain receipts, generation/task IDs, dates, plan/account status, API authorization, download route, and provider terms in a private archive. Verify the Suno and Hoosha terms that applied on the relevant dates.
- **Ambience and SFX:** The metadata records 6 ambience items and 8 sound-effect entries as CC0. Verify their source files and matching license notices individually; do not extend these notices to the soundtrack or artwork.
- **Artwork:** Complete a per-file inventory of image provenance (owner-created, AI-generated, or third-party), tool/source, creation date, applicable terms, and evidence. Do not assume that an AI-generated image automatically has exclusive or commercially unrestricted rights.
- **Fonts and icons:** The repository contains separate license notices for its fonts and icon sets. Preserve those notices in any distribution and re-check them if assets are replaced.

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

**Release decision:** Not ready for an Android store release or commercial distribution until the Android identity/signing setup is verified, the applicable credential is rotated if it was reused, asset rights are documented, legal terms are reviewed, and signed device testing is complete.
