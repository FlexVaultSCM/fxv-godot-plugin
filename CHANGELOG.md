# CHANGELOG

## [0.7.2](https://github.com/FlexVaultSCM/fxv-godot-plugin/compare/v0.7.1...v0.7.2) (2026-09-25)


### Bug Fixes

* revision spec, selection loss, and conflict resolve scoping ([#24](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/24)) ([09f61d8](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/09f61d81f85e15afb870e38b372127748c7c3f31))

## [0.7.1](https://github.com/FlexVaultSCM/fxv-godot-plugin/compare/v0.7.0...v0.7.1) (2026-09-24)


### Bug Fixes

* label unpublished draft revisions as 'unpublished' instead of '-' ([#20](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/20)) ([e3d4b0f](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/e3d4b0f7b15396a7d031037ce83e40460509ec14))

## [0.7.0](https://github.com/FlexVaultSCM/fxv-godot-plugin/compare/v0.6.0...v0.7.0) (2026-09-23)


### Features

* register godot plugin with fxv integration registry ([#18](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/18)) ([9df9ff2](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/9df9ff206c7557e1c55318569b44cd9b22c33e42))
* **ui:** append beta tag to dock plugin version ([#17](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/17)) ([64d6027](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/64d6027f0310a9aeaee11daa80f486465bcd2053))

## [0.6.0](https://github.com/FlexVaultSCM/fxv-godot-plugin/compare/v0.5.1...v0.6.0) (2026-09-22)


### Features

* upgrade fxv-core compatibility to 0.11.0 and add branch swapping ([#15](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/15)) ([ce2f76c](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/ce2f76cca7bd4d0671b489e611546b37be0f783a))

## [0.5.1](https://github.com/FlexVaultSCM/fxv-godot-plugin/compare/v0.5.0...v0.5.1) (2026-09-21)


### Bug Fixes

* pick up FTUE fixes for release versioning ([#13](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/13)) ([c29593b](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/c29593b48892827d9cbf97a617249e0de47902df))

## [0.5.0](https://github.com/FlexVaultSCM/fxv-godot-plugin/compare/v0.4.0...v0.5.0) (2026-09-16)


### Features

* Add auto-snapshot hooks for high-entropy editor operations ([#8](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/8)) ([bafa876](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/bafa876d6e90379d03ac0b640a426f2425ee0e27))
* prompt to exclude .godot/ from .fxvignore on startup ([#7](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/7)) ([d2a54de](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/d2a54debbadd876e4018ccdf296aaa241e24407e))

## [0.4.0](https://github.com/FlexVaultSCM/fxv-godot-plugin/compare/v0.3.0...v0.4.0) (2026-09-15)


### ⚠ BREAKING CHANGES

* the plugin now requires fxv CLI 0.10.1 or newer (previously 0.5.0 to < 0.10.0), matching the status command's schema v2 payload.

### Features

* require fxv CLI 0.10.1 or newer ([#5](https://github.com/FlexVaultSCM/fxv-godot-plugin/issues/5)) ([2c0c983](https://github.com/FlexVaultSCM/fxv-godot-plugin/commit/2c0c983c9b72e793f7c42acdda042867a37ff369))

## [Unreleased]

### Changed
- Version guard now requires `fxv` CLI `0.10.1` or newer (previously `0.5.0` to `< 0.10.0`), matching the `status` command's schema v2 payload.

### Added
- Changes tab shows why a file is conflicted (content/deleted/type-change) as a tooltip, using the `kind` the CLI now reports on `conflict_state`.

## [0.3.0] - 2026-09-10

### Added
- Loading spinner in the toolbar while a CLI operation is in flight.
- Unpublished change count in the status header and "(unpublished)" tags in the Changes tab.
- History tab: **Diff Against Current** and **Diff Against Previous** buttons on the changed-files detail panel.
- **Sync Workspace** button shows the revs-behind count and highlights when the workspace is behind remote.
- Status refreshes immediately on Godot filesystem changes, not just the 10s poll.
- Editor Settings: **Default Resolve Preference** (auto-resolve sync conflicts as Mine/Theirs).
- Editor Settings: **Timeout Seconds** for CLI calls.
- **Project > Tools > FlexVault: Ignore Selection (.fxvignore)**.
- **Project > Tools** actions for the FileSystem dock selection: Revert, Diff Against Base, Resolve (Mine/Theirs).
- Toolbar Log In field wired to `fxv login`.
- History tab changed-files detail panel (via `fxv changeinfo`).

### Changed
- **Publish** now snapshots the workspace before publishing (matches the Unreal/Unity plugins), instead of silently no-op'ing on unsnapshotted changes.
- Changes tab and History tab split panels now default to a 50/50 split.
- Removed the toolbar's **Log Out** and **Refresh** buttons (redundant with auto-refresh; use `fxv logout` directly).
- Changes tab's **Diff Base** renamed to **Diff Against Previous**.
- **Goto**, **Diff Against Previous**, and **Revert Selected** are disabled until something is selected.
- CLI calls now run on a background thread, so the editor no longer freezes during Snapshot/Publish/Sync/Goto/Revert/Resolve.

### Fixed
- Stray collapse/expand arrow above the Changes/History trees (`hide_root` wasn't set).
- History tab revision display didn't match the status header for a synced workspace (spurious `.0` draft suffix).
- **Diff Against Previous** no longer opens an empty diff for files with no real content changes.
- Snapshot/Publish/Sync/Login/Logout/Revert/Resolve/Goto now surface the real CLI error message instead of a generic failure.
- History tab: fixed changeinfo failing for unparented drafts and for drafts with a published parent (int/float revision bug), fixed selection loss/flicker on background refresh, and fixed a generic error masking the real changeinfo failure reason.

## [0.2.0] - 2026-09-10

### Added
- Initial release of FlexVault Godot Plugin (`fxv-godot-plugin`) for Godot 4.x.
- Core CLI execution runner (`FxvRunner`) supporting `--format json`, `--unattended`, and `--no-color`.
- Version guard (`FxvVersionGuard`) enforcing compatible `fxv` CLI range `[0.5.0, 0.10.0)`.
- Data Transfer Objects (`FxvDto`) mapping CLI JSON wire formats.
- Companion file manager (`FxvMetaHelper`) handling Godot `.import` and `.uid` metadata atomicity.
- Workspace safety guards (`FxvSafetyGuards`) preventing mutations during play mode and auto-saving dirty scenes.
- Visual bottom dock panel (`FxvBottomDock`) featuring:
  - Changes tab with multi-file selection, status colors, and file sizes.
  - Draft snapshot and publish controls with description entry.
  - Inline Revert and Conflict Resolution (Mine/Theirs).
  - External visual diff viewer launcher (`FxvDiffHelper`).
  - Workspace sync (`fxv sync`).
  - History tab with revision list and one-click revision switching (`fxv goto`).
- Integration and unit test suite verifying SemVer parsing, companion handling, and JSON deserialization.
