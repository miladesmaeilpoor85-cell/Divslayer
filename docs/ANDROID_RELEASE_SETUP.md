# Production Android release setup — Divslayer
# آماده‌سازی انتشار رسمی اندروید — دیوکش

**Status:** preparation checklist only. No production signing workflow is enabled by this document.

This guide keeps the production signing identity out of the public repository and prevents QA settings from being mistaken for release settings.

## 1. Confirm the app identity before building

Obtain the current private production `export_presets.cfg` from the owner's trusted local backup. Confirm and record privately:

- Exact Android application ID / package name.
- Current version name and next unused, monotonically increasing version code.
- Minimum SDK, target SDK (API 36 or higher for the current Google Play target requirement), architectures, permissions, and asset inclusion/exclusion rules.
- Whether the app has ever been submitted to a store or distributed outside the owner's devices.
- Whether Google Play App Signing is enabled, and whether the local key is an upload key or an app-signing key.

Never substitute the QA identity `com.example.divslayer.qa` for the production package ID. Do not invent a package ID: a wrong application ID creates a separate app and cannot update an existing installation.

### Android ABI policy

- **Production/store build:** enable only `arm64-v8a`. Keep `armeabi-v7a`, `x86`, and `x86_64` disabled in the owner's private production export preset.
- **CI QA build:** enable `arm64-v8a` and `x86_64`; keep `armeabi-v7a` and `x86` disabled. The `x86_64` library is included only so GitHub's x86_64 Android emulator can execute the QA APK.
- This release policy intentionally excludes Android devices running a 32-bit-only system image. Do not assume every low-cost Android phone is 64-bit at the OS/ABI level; confirm the intended device coverage before publishing.
- The private production `export_presets.cfg` is intentionally not stored in this repository. Apply the ARM64-only setting to that private preset and verify the signed APK/AAB's actual ABI metadata before release. The public QA preset is not a production preset.

## 2. Production signing key

- The retired legacy test keystore/key material must never be reused.
- Generate a new production upload/signing key locally with a strong, unique password.
- Verify the certificate fingerprint and record it in the owner's private release inventory.
- Keep at least two secure offline backups in separate protected locations.
- Never commit the keystore, PEM/private key, certificates with private material, passwords, aliases, or export preset containing signing credentials.
- Never send signing material or passwords through chat, email, GitHub Issues, PR comments, or workflow logs.

For Google Play, decide whether to enroll in Play App Signing. If enabled, the developer upload key and Google-held app-signing key are different roles. Keep the upload key secure and follow Google's official [Play App Signing documentation](https://support.google.com/googleplay/android-developer/answer/9842756).

## 3. Protected GitHub Actions environment (only after the private settings are confirmed)

If release export is later automated on GitHub Actions:

1. Create a protected GitHub Environment named `android-production`.
2. Require owner approval before jobs targeting that environment can access production secrets.
3. Restrict the release workflow to a protected release tag or manually approved run from the protected default branch. Do not expose production secrets to pull-request workflows or forked PRs.
4. Use GitHub Actions Environment secrets for the private signing material and credentials, with narrowly scoped access. Use non-secret repository/environment variables only for non-confidential build metadata.
5. Materialize the keystore only under the ephemeral runner's temporary directory with restrictive file permissions; disable shell tracing before secrets are used; never print secret values; remove the temporary file in an always-run cleanup step.
6. Do not upload the keystore, private export preset, credential files, or temporary signing files as workflow artifacts.
7. Verify the output's package ID, version code, SDK levels, ABIs, permissions, signing certificate fingerprint, and artifact checksum before publishing anything.

Suggested secret names for a future reviewed workflow (names only; do not create values in source files):

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`

A production export preset may contain additional private application settings. Keep it outside the repository; choose a protected secret or a separately controlled secure input only after reviewing size limits and the exact contents. Do not store a preset containing passwords in a plain repository variable.

## 4. Build and verification gates

Before enabling a production workflow:

- Reproduce the private production export locally using the intended Godot 4.7.2 version and matching export templates.
- Export a signed Android App Bundle (AAB) for Google Play; create a signed APK separately only when direct distribution is intended.
- Validate the bundle structure and manifest with Android's official bundle tooling.
- Verify the signature and compare the signing certificate fingerprint with the private release inventory.
- Check the exact production package ID, version code, min/target SDK, architectures, permissions, and included resources.
- Test through Google Play's internal testing track when Play App Signing is used; also test clean install, update behavior, save migration, lifecycle, touch controls, and representative low-/mid-range devices.
- Keep QA APKs separate from production artifacts, package IDs, credentials, release tags, and store uploads.

A green QA workflow is not a production release approval. The currently available `0.43.0-qa` artifact uses the separate package `com.example.divslayer.qa` and a temporary debug key.

## 5. Inputs still required before implementation

The production workflow must not be enabled until the owner has verified:

- The exact production package ID and current version code.
- The private production export settings and target store/distribution channel.
- The new production/upload signing key has been generated and backed up.
- The certificate fingerprint has been recorded privately.
- The protected GitHub Environment and required secrets have been configured, if cloud signing is selected.
- Asset-rights, legal, privacy, and physical-device release gates are complete.

Keep the real package ID and signing material in the owner's private records. The public repository needs only the reviewed workflow and non-sensitive release metadata.
