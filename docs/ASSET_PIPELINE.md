# Asset pipeline | خط تولید دارایی‌های دیوکش

This document describes the repository-side asset checks. It requires no desktop application to be installed by the game owner: the checks run automatically in GitHub Actions whenever a pull request or push triggers Godot CI.

## Automated checks

`tools/asset_audit.py` uses only the Python standard library and:

- inventories PNG, JPEG, and WebP artwork under `assets/art/`;
- checks basic file/container headers and extracts image dimensions;
- confirms that each artwork file has exactly one row in `docs/ASSET_RIGHTS_REGISTER.csv`;
- rejects duplicate registry paths, paths outside the artwork directory, missing files, and unregistered images;
- reports exact duplicate image files, unusually large files, and very large dimensions;
- checks basic container signatures for OGG, WAV, MP3, and FLAC assets under `assets/audio/`;
- reports the register's existing rights-status values.

The script intentionally treats `UNVERIFIED` or blank rights states as warnings, not as technical failures. That allows the team to keep improving the game without falsely claiming that unresolved artwork is commercially cleared. Missing or unsafe register entries and unreadable asset headers fail CI.

## Running it

The project CI runs:

```sh
python3 -m unittest discover -s tools -p "test_asset_audit.py" -v
python3 tools/asset_audit.py
```

For a machine-readable report:

```sh
python3 tools/asset_audit.py --json
```

No dependency installation is required. The game owner only needs to download and test a QA APK when a gameplay build is produced; this audit is run by GitHub's hosted runner.

## Adding or replacing an asset

Before submitting a new image, add exactly one row to `docs/ASSET_RIGHTS_REGISTER.csv`. Record the actual creator/source, generation or editing tool, date, applicable terms, commercial-use status, and a private evidence reference where available. Do not change a status to verified unless the supporting evidence has actually been checked.

The audit checks that the register and files match; it does **not** determine authorship, inspect prompts or source files, provide legal advice, or guarantee that an image/audio file is creatively suitable. Audio metadata and legal evidence require separate human review.
