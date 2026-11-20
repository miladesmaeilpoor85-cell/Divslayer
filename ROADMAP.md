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

## 3. Visual upgrade program / برنامهٔ ارتقای بصری

- [x] Establish the Persian-mythology visual direction and class-specific design rules in `docs/ART_DIRECTION_GUIDE.md` and `docs/CLASS_VISUAL_DESIGN.md`.
- [x] Audit the current hero/enemy animation inventory and record the one-pose hero attack limitation; see PR #42 and `docs/ANIMATION_PRODUCTION_PLAN.md`.
- [x] Define a staged quality-upgrade program covering character art, combat animation, VFX, and environments; see `docs/VISUAL_UPGRADE_PROGRAM.md`.
- [ ] Complete visual approval of the Warrior Starter multi-frame attack candidate in PR #43; the PR is not merged and its CI pass is not a substitute for native-scale/device art review.

### 3.1 Character art / طراحی شخصیت‌ها

- [ ] Upgrade Warrior Starter as the first quality benchmark without changing its identity, equipment logic, foot pivot, or gameplay hitbox.
- [ ] Apply the approved character-art standard to Mage, Rogue, and Paladin Starter; each class must have distinct silhouettes, tools, materials, palette accents, and acting.
- [ ] Extend approved class designs to Mid and Endgame equipment looks only after the Starter designs pass mobile-scale review.
- [ ] Verify all three directions, transparency, foot baseline, weapon/hand continuity, and readability at the actual Android render scale.

### 3.2 Combat animation / انیمیشن مبارزه

- [ ] Produce genuine authored light-attack, heavy-attack, follow-through, and recovery poses; do not count transform-only motion or repeated frames as new animation.
- [ ] Add class-specific guard/block, parry, hit/stagger, dodge/dash, finisher/ultimate, and death sequences in a staged order.
- [ ] Align contact frames with gameplay impact timing, projectile release, hit-stop, cancel windows, and existing combat tests.
- [ ] Review important enemy and boss attack tells after hero combat clips are stable.

### 3.3 Visual effects / جلوه‌های بصری

- [ ] Improve sword trails, impact sparks, hit bursts, dust, debris, light flashes, and readable recovery effects using the existing `scripts/fx/fx.gd` and `scripts/bossfx.gd` systems as the integration baseline.
- [ ] Add class/skill-specific effects for Warrior, Mage, Rogue, and Paladin without hiding targets, hitboxes, telegraphs, or touch controls.
- [ ] Refine cloth, foliage, ambient particles, and spell motion where they add readable motion rather than background noise.
- [ ] Verify both normal and reduced-FX settings on Android and record frame-time/memory impact.

### 3.4 Environment art / گرافیک محیط

- [ ] Upgrade the forest, dungeon, village, and Alborz area kits in separate reviewable batches: terrain, paths, architecture, trees, rocks, props, lighting, and atmospheric layers.
- [ ] Replace the Alborz prototype's reused Frostvale ground only after the dedicated Alborz ground and its map-scale/import review are complete.
- [ ] Keep collision and navigation geometry in map data; never encode gameplay collision solely as painted pixels.
- [ ] Validate every area at native phone scale and across the low/high graphics settings.

See [visual upgrade program](docs/VISUAL_UPGRADE_PROGRAM.md), [animation production plan](docs/ANIMATION_PRODUCTION_PLAN.md), and [Alborz art production brief](docs/ALBORZ_ART_PRODUCTION_BRIEF.md).

## 4. Asset rights and legal readiness / حقوق دارایی‌ها

- [x] Create a per-image rights register covering the current image files.
- [ ] Verify provenance and commercial-use status for all 371 registered image entries.
- [ ] Collect Suno/Hoosha receipts, generation IDs, dates, paid-plan evidence, API/download authorization, and dated terms for all 30 soundtrack tracks.
- [ ] Verify CC0 source/notice for each ambience and SFX file without extending those terms to unrelated assets.
- [ ] Obtain qualified legal review of the license, CLA, privacy statements, and distribution terms before public contributions or commercial release.

## 5. Secure Android release / انتشار امن اندروید

- [x] Isolated Android QA export and signature-verification workflow.
- [x] Latest current-main QA APK exported from commit `0f20e499bf17966a9edb3639a4373205be048edd` (run 44710183868, artifact 14617302636; expires 4 December 2026).
- [ ] Verify production package ID and export settings from the owner's private export preset.
- [ ] Generate a new production signing/upload key locally and keep two secure offline backups.
- [ ] Decide on Google Play App Signing and preserve package/update continuity if already distributed.
- [ ] Produce and verify a production AAB; do not substitute the QA package or key.
- [ ] Complete physical-device install/update/save/lifecycle/touch/performance tests and owner approval before release.

## 6. Art, audio, and performance quality / کیفیت هنری، صوتی و کارایی

- [x] Krita, Audacity, LMMS, and Blender smoke-test workflow available in CI.
- [ ] Establish consistent visual review and texture/overdraw budgets for each new asset batch.
- [ ] Create and review final area-specific ambience/music rather than relying on temporary aliases.
- [ ] Maintain the target mobile frame-time budget during combat and high-particle scenes.
