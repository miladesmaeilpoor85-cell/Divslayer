# Asset-rights evidence requirements

**Status checked: 26 November 2026.** This is an evidence checklist, not a legal opinion or a declaration that the listed assets are cleared.

## Current recorded status

- The image rights register contains 403 image rows marked `UNVERIFIED` in the checked main snapshot.
- The repository identifies 30 soundtrack tracks as generated through the Suno V6 / Hoosha route; their commercial-use evidence is still `UNVERIFIED`.
- The register has no usable private proof reference for those outstanding image entries. The music records also lack the per-track evidence listed below.
- A tool-generated asset, a paid subscription, or the presence of a file in this repository is not by itself proof that the owner has all required commercial rights.

Do not change any entry to `VERIFIED` until the evidence for that exact file is checked and a private proof reference is recorded.

## 1. AI-generated images and character/environment art

For each image, record:

1. Exact repository path and cryptographic file hash.
2. Creator/owner and generation provider/tool.
3. Original generation ID, job/task ID, and creation date/time.
4. Account plan and proof that the plan was active for the relevant generation/download event, where the provider's terms make that relevant.
5. The dated Terms of Service or commercial-use grant that applied to that specific output.
6. Evidence of any restrictions on use, distribution, editing, training, exclusivity, or commercial exploitation.
7. A private evidence reference, such as a securely stored receipt/export/terms snapshot, without publishing account identifiers, private messages or credentials.

Where an image was drawn or supplied by a human artist, obtain a written assignment or licence identifying the work, permitted commercial uses, derivative/modified use, distribution platforms, duration, territory, and attribution requirements.

## 2. Suno V6 / Hoosha soundtrack tracks

For each of the 30 tracks, record:

1. Repository path, track title, file hash, Suno generation ID and Hoosha task/job ID.
2. Generation date and account-plan proof for that date.
3. Download/export date, exact download route and proof that the route was permitted under the applicable Suno terms.
4. Hoosha's written authority for the API/download path and the rights it passes through for the output.
5. The dated Suno Terms and paid-plan help/policy pages that applied at generation and download.
6. Receipt/invoice or other reliable subscription proof, stored privately.
7. Any provider restrictions, attribution obligations, commercial limitations, or notice requirements.

A paid plan alone is not enough unless the plan and the exact generation/download path satisfy the applicable terms. Keep each track `UNVERIFIED` until its individual record is complete and reviewed.

## 3. CC0 ambience and sound effects

For each file claimed as CC0:

- Match the exact audio file to its source pack and original source page.
- Retain the pack's own `License.txt` or the asset's CC0 1.0 declaration and a dated source-page snapshot.
- Record author/source, source URL, downloaded filename, repository filename and file hash.
- Check whether attribution or other notices are requested and retain the notice even if CC0 waives copyright restrictions.

Do not extend a CC0 notice from one pack to files from another provider or to soundtrack music.

## 4. Fonts and icons already carrying repository notices

- Keep `assets/fonts/Cinzel-OFL.txt` and `assets/fonts/Vazirmatn-OFL.txt` with the fonts they cover. Confirm the exact font files and any reserved font-name conditions against OFL 1.1 before redistribution.
- Keep `data/icons-LICENSE-lucide.txt` with the icon data. The notice records the applicable ISC terms and the MIT notice for Feather-derived icons.
- A font/icon notice does not grant rights to unrelated illustrations, characters, textures or music.

## 5. Legal documents and distribution terms

Before accepting public contributions or commercial distribution, obtain qualified legal review of:

- the provisional proprietary `LICENSE` and the draft `CLA.md`;
- contributor warranties, ownership/assignment language, third-party assets and AI-provider output terms;
- privacy, telemetry, store listing, refund/support and distribution terms;
- brand/trademark clearance for the title, logos, names and visual identity.

## 6. Evidence storage and change control

- Store receipts, account screenshots, contracts, private provider correspondence and personal account details outside the public repository in a controlled, backed-up location.
- Put only a non-sensitive proof reference in `proof_reference_private_location` in the register.
- Record reviewer, review date, relevant terms version/date, and the reason for the status decision.
- Keep `UNVERIFIED` when proof is missing, ambiguous, conflicts with provider terms, or cannot be matched to the exact file.
- Never commit signing keys, passwords, API keys, account tokens or unredacted payment/account records.

## 7. Acceptance checklist

- [ ] Every image row has source/creator/provider, creation date, applicable terms, status and private proof reference.
- [ ] All 30 soundtrack rows have independent per-track generation and permitted-download evidence.
- [ ] Each CC0 ambience/SFX file is matched to the correct pack licence and source notice.
- [ ] Font and icon notices remain present and are matched to the correct files.
- [ ] Legal counsel has reviewed the provisional licence, CLA, privacy and distribution terms.
- [ ] An independent final audit finds no unexplained asset, missing notice or false positive `VERIFIED` status.

Until these conditions are satisfied, commercial release remains blocked on asset-rights grounds.