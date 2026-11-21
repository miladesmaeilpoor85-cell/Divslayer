# Hero starter-tier multi-frame attacks

This change registers the owner-supplied Rogue and Paladin starter attack atlases. Warrior is intentionally not replaced: the main branch already has a four-frame Warrior Starter attack sequence registered as individual PNGs. Mage is not activated in this change because four source cells have zero-pixel left/right margin and may clip the staff/effect; it remains on the original single-pose attack until a corrected atlas passes review.

## Runtime contract

Each new atlas is 640 × 468 px and contains a 4-column × 3-row grid of 160 × 156 px cells. Rows are `down`, `up`, `side`; columns are `anticipation`, `windup`, `contact`, `recovery`. The runtime uses the existing `attackSheet` loader in `scripts/sheets.gd`; no combat code or damage values are changed.

The Rogue and Paladin entries use `attackFrames: 4`, `attackFps: 24`, and `attackImpactFrame: 2` (zero-based third frame). The nominal clip duration is 4/24 s ≈ 0.167 s and the impact point is 2/24 s ≈ 0.083 s, matching the existing multi-frame attack contract.

## Import and review notes

The uploaded source sheets were padded to 1536 × 1152 px without cropping any source row, then split using the repository's 4×3 atlas importer. The importer writes the final 640 × 468 transparent packed atlases and 160 × 156 output frames. Rogue uses the explicit global key mode to clear enclosed magenta matte islands from its white slash effects. Magenta backgrounds were removed on Mage, Rogue and Paladin; Rogue used the importer's explicit `--global-key` mode because magenta-colored matte islands were enclosed by the pale slash effects. Warrior's embedded neutral checkerboard was removed as a separate review-only alternative atlas.

Exact duplicate detection found no duplicate frame pairs across the four reviewed source atlases. All adjacent frame pixel-change ratios exceeded the review threshold of 2.5%. Some source poses approach their cell edges; the importer records exact per-frame source margins and emits warnings under 8 px. These flagged frames require visual QA and have not been silently cropped or reconstructed. The art is retained without silently cropping or inventing replacement poses. The Warrior review atlas is not runtime-registered.

## Rights status

The new PNG files are recorded in `docs/ASSET_RIGHTS_REGISTER.csv` with status `UNVERIFIED`. The connected generation workspace confirms the generation tasks, but the project owner must retain/review the provider terms and confirm commercial-use permission. Technical integration does not constitute legal clearance.

## Validation

Pull-request CI must pass the full Godot 4.7.2 headless suite, asset/rights audit and Android QA APK workflow. Android emulator launch must be successful before merging. The generated QA package is a debug/test APK, not a Play Store release.
