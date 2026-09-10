# CHANGELOG

## [Unreleased]

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
