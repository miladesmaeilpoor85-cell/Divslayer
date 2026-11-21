# Roadmap | نقشه راه

Planning document, not a promise of delivery dates. این سند برنامه‌ریزی است و تعهدی درباره تاریخ انتشار ایجاد نمی‌کند.

## 1. Repository and source integrity / زیربنای مخزن

- [x] Public source-available repository and bilingual project overview.
- [x] Godot source imported; Android signing material and private export preset excluded from the public tree.
- [x] Godot, GDScript, Python, image/map, audio, and Android QA workflows established.
- [x] Artwork inventory and one-to-one coverage check created.
- [ ] Complete legal review of the provisional proprietary license and draft CLA.
- [ ] Confirm old-clone and GitHub cache/credential follow-up is fully closed.

## 2. Gameplay and Chapter IV / گیم‌پلی و فصل چهارم

- [x] Deterministic warning/active/rest wind controller with bounded drift and safe reset.
- [x] Weather-aware ambient drift, directional dodge trails, and the Thornwood parley/fight persistence fix integrated into `main` through PR #38.
- [x] Alborz map, wind shelters, guard encounter, scout rescue, save-backed chapter flow, and return route integrated into `main`.
- [x] High Eyrie side-area and three-phase Gale Warden encounter integrated through PR #37.
- [x] Owner-reported physical Android smoke test of the integrated Alborz route recorded in PR #38; repeat the full acceptance route on each release candidate.
- [ ] Replace temporary/reused Alborz ground, scout visuals, props, route markers, and ambience with dedicated, rights-reviewed production assets.
- [ ] Tune wind, collision, damage, and combat readability at native mobile scale for all four classes.

## 3. Character animation / انیمیشن شخصیت‌ها

- [x] Audit all 12 hero appearances and the 36 directional attack clips.
- [x] Add validated attack-atlas import, runtime loading, frame-level contact timing, and animation review tools.
- [x] Integrate four-frame, three-direction light attacks for Warrior Starter (12 transparent PNGs).
- [x] Integrate four-frame, three-direction light attacks for Rogue Starter (separate atlas loaded from Base64 resource parts).
- [x] Add class-specific melee contact VFX and cancelable attack-anticipation cues; these are presentation effects, not authored sprite frames.
- [ ] Create and review genuine four-frame attack art for Mage Starter and Paladin Starter.
- [ ] Extend class-specific light-attack art to Warrior, Mage, Rogue, and Paladin Mid/Endgame looks.
- [ ] Produce dedicated heavy attack, hit/stagger, block, dodge, and death animation sets for all four classes.
- [ ] Complete native Android-scale visual review, gameplay timing checks, provenance records, and asset-rights verification for each accepted animation batch.

See [animation pipeline](docs/ANIMATION_PIPELINE.md), [production plan](docs/ANIMATION_PRODUCTION_PLAN.md), and [visual upgrade program](docs/VISUAL_UPGRADE_PROGRAM.md).

## 4. Dedicated environment art / گرافیک اختصاصی محیط

- [ ] Replace the Alborz prototype's Frostvale ground with a dedicated Alborz ground asset.
- [ ] Create the scout sprite/look and dialogue portrait; replace reused props and route markers.
- [ ] Review procedural wind cues against final art and add dedicated ambient wind audio if needed.
- [ ] Register every new art/audio file with source, terms, commercial-use status, and private evidence reference.

See [Alborz art production brief](docs/ALBORZ_ART_PRODUCTION_BRIEF.md).

## 5. Asset rights and legal readiness / حقوق دارایی‌ها

- [x] Create a per-image rights register covering the current image files.
- [ ] Verify provenance and commercial-use status for all 371 registered image entries.
- [ ] Collect Suno/Hoosha receipts, generation IDs, dates, paid-plan evidence, API/download authorization, and dated terms for all 30 soundtrack tracks.
- [ ] Verify CC0 source/notice for each ambience and SFX file without extending those terms to unrelated assets.
- [ ] Obtain qualified legal review of the license, CLA, privacy statements, and distribution terms before public contributions or commercial release.

## 6. Secure Android release / انتشار امن اندروید

- [x] Isolated Android QA export and signature-verification workflow.
- [x] Export, package identity, and APK signature verification succeeded for the latest main QA build; the emulator installed the APK and left the Godot activity in the foreground.
- [x] Pass the corrected Godot 4.7.2 emulator startup assertion in PR #56; run 202 succeeded and published installable QA artifact 14707328088 with SHA-256. PR #56 remains open pending review/merge.
- [ ] Verify production package ID and export settings from the owner's private export preset.
- [ ] Generate a new production signing/upload key locally and keep two secure offline backups.
- [ ] Decide on Google Play App Signing and preserve package/update continuity if already distributed.
- [ ] Produce and verify a production AAB; do not substitute the QA package or key.
- [ ] Complete physical-device install/update/save/lifecycle/touch/performance tests and owner approval before release.

## 7. Art, audio, and performance quality / کیفیت هنری، صوتی و کارایی

- [x] Krita, Audacity, LMMS, and Blender smoke-test workflow available in CI.
- [ ] Establish consistent visual review and texture/overdraw budgets for each new asset batch.
- [ ] Create and review final area-specific ambience/music rather than relying on temporary aliases.
- [ ] Maintain the target mobile frame-time budget during combat and high-particle scenes.
