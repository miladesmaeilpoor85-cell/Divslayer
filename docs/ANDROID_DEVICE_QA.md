# Android device QA plan | برنامهٔ آزمون روی دستگاه اندروید

**Scope:** manual validation of the signed Android build on physical devices. This plan is not evidence that a device test has already passed.

## 1A. Download an isolated QA APK from GitHub Actions

The repository provides a non-release debug build workflow. It uses Godot 4.7.2, a QA-only Android package identifier (`com.example.divslayer.qa`), and a temporary debug signing key generated inside the runner. It does not read or use the owner's private export preset, release package identifier, or release keystore.

- Open the repository's **Actions** tab and select **Android QA APK**.
- Open the completed run and download the **Divslayer-Android-QA-APK** artifact.
- Extract the ZIP and install `Divslayer-QA.apk` on the phone. Android may ask you to allow installation from the browser or file manager used to open it.
- This QA app installs separately from any production app. It is not the production package and cannot be uploaded to Google Play.
- The debug key is temporary and newly generated for each workflow run. To install a later QA artifact, uninstall the prior QA app first; its local save will be deleted. Keep the production app installed if present.

This artifact is suitable for first-pass gameplay, boss phase/pool, touch, layout, and performance checks. It is **not** suitable for verifying production app updates, production save migration, or the release signing identity. Those require the private production package ID and the same private signing key across builds.

## 1. Preconditions and protected files

- Use Godot 4.7.2 and matching Android export templates.
- Obtain the owner's private `export_presets.cfg` and the established Android package ID, version code, SDK settings, architectures, and permissions. These are intentionally not present in the public repository; do not invent replacements.
- Use the original release keystore and a private backup. Do not upload keystores, PEM/certificate files, signing passwords, or aliases to GitHub or chat.
- Export a signed test APK/AAB locally. Preserve the same package ID and signing identity for update tests.
- Back up any existing game save before installing or updating.

## 2. Device coverage and test record

Test on at least:
1. The lowest-spec Android device the project intends to support.
2. A representative mid-range device.
3. A current higher-performance device.

Use different screen sizes/aspect ratios where available. For every device record:

| Field | Value to record |
|---|---|
| Device model and Android version | |
| SoC / GPU and RAM | |
| Display resolution and refresh rate | |
| APK version code and package ID | |
| Godot renderer | GL Compatibility |
| Free storage before install | |
| Test date and build commit | |

Do not define the minimum Android version or package ID from this public repository: they are controlled by the missing private export preset.

## 3. Install, update, and lifecycle

- Install the signed APK from a clean state; launch, start a new game, save, close fully, and relaunch.
- Update over the previous signed build using the same package ID and signing key. Confirm the save and progression remain readable.
- Put the app in the background during gameplay, resume it, lock/unlock the device, and repeat after a boss encounter.
- Confirm the app stays in the intended landscape orientation and that important HUD elements and touch controls are not obscured by cut-outs, navigation bars, or rounded corners.
- Check that Android Back behavior returns to the game's expected pause/menu flow and does not corrupt or unexpectedly reset the save.

## 4. Boss phase and poison-pool regression

Use a repeatable boss encounter, including the Sorceress/Matriarch poison-pool fight where available.

1. Allow the boss to create a poison pool. Stand inside it long enough to verify the expected health/status effect, then move outside and verify no further pool damage is applied.
2. Cause the boss to cross the 66% phase threshold while a projectile and poison pool from the previous phase are active.
3. Verify the previous phase's projectiles and pools disappear at the phase transition. The player must not receive delayed damage or poison from those cleared effects.
4. Repeat at the 33% threshold/final phase.
5. Defeat the boss while its projectiles and pools are active. Verify no old effect continues to damage the player after victory.
6. Repeat a rematch or re-enter the encounter. Verify no effect from the previous fight appears in the new encounter.
7. Confirm the new phase's attacks and newly created poison pools still work normally.

Record a short screen capture and note the boss, phase, player position, health before/after, status icons, and whether any old visual/effect remains.

## 5. Touch controls and layout

- Move with the joystick while attacking; repeat with a held attack to trigger the charged/heavy version.
- Move and dodge in quick succession; test block/parry, both spell buttons, ultimate, and potion buttons when unlocked.
- Hold movement or attack, open pause/dialogue, then lift the finger. Confirm movement/charging/blocking stops rather than remaining latched.
- Test two simultaneous touches (movement + attack/dodge).
- Test both right-handed and left-handed layouts.
- Check all touch targets can be reached without covering the hero, boss health bar, dialogue, or essential HUD.

## 6. Performance, memory, and thermal behavior

Run a 20–30 minute session on each device, including a boss fight with multiple telegraphs, projectiles, particles, and poison pools.

Record:
- Average frame rate and worst sustained frame-rate drops during exploration and boss fights.
- Frame time (16.7 ms is the budget for 60 FPS; 33.3 ms for 30 FPS).
- Peak memory/RAM if tooling exposes it.
- Device temperature/throttling observations, battery drain, crashes, freezes, and audio dropouts.
- Any stutter when effects spawn, phase transitions occur, or the boss dies.

Choose the actual target frame rate for each device tier before judging pass/fail. Do not treat a single instantaneous FPS reading as a performance result.

## 7. Acceptance criteria

A device/build passes this QA pass only when:
- Fresh install and update install both work with the established app identity and preserve saves.
- No projectile or damaging pool from a prior boss phase or fight remains active after phase transition or boss death.
- Current-phase attacks and poison pools still apply their intended effects.
- Simultaneous touch controls and release-during-pause behave consistently.
- No crash, freeze, persistent input, save corruption, or blocking UI/layout defect occurs during the session.
- Performance measurements meet the project's explicitly chosen target for that device tier.

## 8. Test report

| Device | Install/update | Phase II/III cleanup | Boss death cleanup | Touch/layout | FPS/frame time | RAM/thermal | Result / notes |
|---|---|---|---|---|---|---|---|
| Low-spec target | | | | | | | |
| Mid-range | | | | | | | |
| Higher-performance | | | | | | | |

### Initial user-reported smoke test — 2026-11-18

- **Build:** Divslayer QA `0.39.0-qa`, GitHub Actions run [`44277080841`](https://github.com/miladesmaeilpoor85-cell/Divslayer/actions/runs/44277080841), source commit [`9d3fc3184ff0b4dc812478834696448ab662a49d`](https://github.com/miladesmaeilpoor85-cell/Divslayer/commit/9d3fc3184ff0b4dc812478834696448ab662a49d).
- **User-reported outcome:** the user installed and launched the game and reported that it ran without apparent problems or lag.
- **Not yet recorded or verified:** device model, Android version, session duration, measured FPS/frame time, boss phase/death cleanup, multitouch behavior, pause/resume, save persistence, and thermal behavior.

This is a positive initial smoke-test report, not a complete pass of the physical-device QA checklist above.
