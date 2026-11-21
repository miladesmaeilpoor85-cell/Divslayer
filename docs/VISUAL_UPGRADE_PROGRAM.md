# Visual and animation upgrade program | برنامهٔ ارتقای بصری و انیمیشن Divslayer

**Status checked:** 21 November 2026  
**Baseline:** main `6fdc3c5176fbf87b07d59e1910fcdce26ebf4df2`, project version 0.43.0.

This is a staged production plan, not a claim that all art work is complete. Preserve Divslayer's Persian-mythology / Shahnameh-inspired identity and its current readable action-RPG presentation.

## 1. Verified animation baseline

- 12 hero appearance looks: Warrior, Mage, Rogue, Paladin, each with Starter, Mid, and Endgame equipment.
- 36 directional hero attack clips in the manifest (three directions per look).
- **Six multi-frame directional light-attack clips:** Warrior Starter and Rogue Starter each have four real frames per direction (down/up/side).
- **30 directional attack clips remain single-pose:** Warrior Mid/Endgame; Mage Starter/Mid/Endgame; Rogue Mid/Endgame; Paladin Starter/Mid/Endgame.
- Mage Starter and Paladin Starter still need their first approved, class-specific attack frames.
- The existing frame-level pixel audit in `tools/animation_quality_audit.py` and CI tests report duplicates, low motion, alpha coverage, and alignment cues. These are triage signals, not an artistic quality score.
- Procedural impacts, anticipation cues, slash arcs, dodge trails, and hit flashes are VFX; they are not additional authored character poses.

See [Animation Pipeline](ANIMATION_PIPELINE.md), [Animation Quality Audit](ANIMATION_QUALITY_AUDIT.md), and [Character Animation Production Plan](ANIMATION_PRODUCTION_PLAN.md).

## 2. Non-negotiable art rules

1. Preserve the current hero identity, weapon/shield/staff, costume details, palette, scale, transparency, pivot, and directional conventions unless a reviewed replacement is explicitly approved.
2. A new frame must show a genuinely new pose: changed limb positions, torso balance, weapon orientation, cloth motion, or contact posture. Translation, rotation, recolouring, squash/stretch, or a trail drawn behind one still image does not count as authored animation.
3. Do not borrow a generic European fantasy silhouette or replace Persian-inspired details with unrelated motifs. Use the project's [Art Direction Guide](ART_DIRECTION_GUIDE.md) and [Class Visual Design](CLASS_VISUAL_DESIGN.md).
4. Do not change damage, hitboxes, reach, cooldowns, or class balance as a side effect of visual work.
5. Review every frame at native pixel size, on light/dark backgrounds, and at actual Android display scale.

## 3. Character and combat animation sequence

### Stage A — validate existing Warrior Starter and Rogue Starter

- Compare each new attack frame against its base look so the character does not visually transform during an attack.
- Check footline/pivot, alpha edges, mirrored side-facing weapon/hand placement, and frame-to-frame cadence.
- Verify contact frame index 2 at the current 24 FPS against actual light-attack duration; do not change impact timing until gameplay regression tests pass.
- Review Rogue's Base64-assembled atlas after decoding; confirm all cells have consistent 160×156 dimensions and no edge clipping.
- Keep the legacy base sheet as fallback until the new sequence passes art, rights, and device review.

### Stage B — Mage Starter

Author a separate four-frame attack strip for down/up/side:
- anticipation: staff and casting hand gather energy;
- wind-up: robe/arm/staff movement increases, but no projectile is emitted yet;
- release/contact: clear staff thrust or cast-release pose, matching the actual attack system;
- recovery: hand, staff and robe return to a stable idle/walk-ready pose.

Preserve the Starter Mage's exact identity and staff. Do not draw a projectile in a frame if the gameplay system launches it separately.

### Stage C — Paladin Starter

Author a separate four-frame attack strip for down/up/side:
- anticipation: shield and weapon settle into a guarded stance;
- wind-up: planted feet and clear weapon preparation;
- contact: weapon strike reads independently of the shield;
- recovery: shield remains on the correct arm and the stance returns to guard.

Preserve armor, shield side, weapon identity, and grounded center of mass. Avoid generic crosses or symbols inconsistent with the project's Persian visual language.

### Stage D — expand equipment tiers

After Starter validation, extend class-specific attack motion to Warrior, Mage, Rogue and Paladin Mid/Endgame. Do not copy Warrior poses to the other classes or use recolour-only variants. Each tier must preserve the class silhouette while adding coherent equipment changes.

### Stage E — complete action coverage

Build and review separate clips for:
- heavy attack / committed attack;
- hit and stagger;
- block and parry;
- dodge and dash;
- death and recovery;
- class ultimates only where the runtime has matching, implemented mechanics.

Every clip needs a defined frame rate, impact/release frame, cancel rules, and test coverage.

## 4. Combat VFX and readability

The runtime already has class-specific melee contact responses and procedural anticipation/effect cues. The next pass should:
- keep impact position tied to the actual contact frame and hit result;
- distinguish light and heavy strikes by weight, trail length, impact pause, and recovery, not only by colour;
- preserve enemy silhouettes, boss telegraphs, target health bars, and touch controls;
- review effects at low/high quality settings and measure frame-time cost on Android;
- test dodge/block/death/map-change cancellation to prevent delayed hits or persistent effects.

Any damage or hitbox adjustment is a separate gameplay change with its own regression tests.

## 5. Chapter IV / Alborz environment pass

The Alborz pass, wind controller, shelter logic, scout rescue, return route, High Eyrie side area, and three-phase Gale Warden are integrated in the main gameplay code. They remain a playable prototype slice, not final art.

The [Alborz Art Production Brief](ALBORZ_ART_PRODUCTION_BRIEF.md) identifies the remaining dedicated assets:
- replace reused Frostvale ground with a dedicated high-altitude Alborz ground texture;
- create dedicated wind-carved rock/shelter pieces, ledges and rubble;
- create cloth streamers, poles and cairns for route readability;
- replace the reused Hesk look with a distinct Alborz scout sprite and dialogue portrait;
- replace the procedural Gale Warden silhouette with reviewed character art and real animation;
- create a dedicated wind ambience bed and gust cues after checking audio rights.

Do not remove current fallbacks until replacement assets are imported, rights-registered, and validated with map/collision previews and Android gameplay tests.

## 6. Acceptance gates for every art batch

- [ ] Source/provider/tool, creation date, licence/terms, commercial status, and private evidence reference recorded before production inclusion.
- [ ] No visual identity drift across directions or during attack transitions.
- [ ] Alpha, clipping, frame size, pivot, and weapon orientation checked.
- [ ] Frame sequence visually inspected at native and Android scale.
- [ ] FPS, impact/release timing, cancel rules and hit windows regression-tested.
- [ ] Godot, image-decode, map-preview, animation-audit, and Android QA workflows pass.
- [ ] Physical-device review recorded; emulator startup alone is not gameplay acceptance.
- [ ] No new rights or licensing claim inferred from a successful CI run.

## 7. Release and rights boundary

The visual pipeline is not commercially cleared merely because an asset is present in the repository. The current `docs/ASSET_RIGHTS_REGISTER.csv` has 399 image rows, all marked `UNVERIFIED`. All 30 soundtrack tracks are recorded as Suno V6 generations through the Hoosha API, but the owner-side plan receipts, generation IDs, API/download authorization, and date-specific terms have not been independently established in the repository.

Keep private receipts and account details outside GitHub. Do not upload credentials, keys, private export presets, receipts containing personal account details, or private evidence to issues or public pull requests. Record a safe private evidence reference in the register and retain the underlying documents offline.

## 8. Next production order

1. Physical-device QA of the current 0.43.0-qa baseline and verify the current Warrior/Rogue attack sets at phone scale.
2. Mage Starter attack frames and tests.
3. Paladin Starter attack frames and tests.
4. Mid/Endgame class-specific attacks, followed by heavy/hit/block/dodge/death coverage.
5. Dedicated Alborz/High Eyrie art and ambience.
6. Rights verification, legal review, then production release testing.

These stages are intentionally sequenced; they do not imply dates or automatic approval.
