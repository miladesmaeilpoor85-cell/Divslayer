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
- [x] Generic World/Player integration for optional map-defined wind zones.
- [x] Port weather-aware ambience from PR #25 into the coordinated integration branch; combined FX/Godot CI passed.
- [x] Port dodge trails and the Thornwood parley state fix from PR #26; combined FX and Toll regressions passed.
- [x] Combine PRs #25, #26, and #36 on one draft integration branch; all four Godot shards and focused gameplay regressions passed. See [integration review](docs/INTEGRATION_REVIEW_2026-11-20.md).
- [ ] Complete the Alborz physical-device route: entry/return, gusts, shelters, guards, rescue, save, quit, and reload.
- [ ] Add the optional eyrie route and dedicated wind boss after the core pass is stable.
- [ ] Tune wind, collision, damage, and combat readability for all four classes.

## 3. Character animation / انیمیشن شخصیت‌ها

- [x] Audit the existing hero atlases and identify the one-pose attack limitation.
- [x] Add future-facing loader/impact-frame and preview infrastructure.
- [ ] Author and review genuinely distinct Warrior light/heavy attack frames.
- [ ] Add Warrior hit, block, dodge, idle, and death frames.
- [ ] Produce class-specific Mage, Rogue, and Paladin sequences; do not recolour/reuse Warrior motion.
- [ ] Register real frames in the production art manifest and test timing/hit contact at phone scale.

See [animation production plan](docs/ANIMATION_PRODUCTION_PLAN.md).

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
- [x] Latest current-main QA APK exported from commit `0f20e499bf17966a9edb3639a4373205be048edd` (run 44710183868, artifact 14617302636; expires 4 December 2026).
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
