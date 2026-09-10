# CHANGELOG

## [Unreleased]

### Added
- **Project > Tools > FlexVault: Ignore Selection (.fxvignore)** appends the current
  FileSystem dock selection, plus their companion `.import`/`.uid` files, to
  `.fxvignore`, mirroring into `.gitignore` if one is present. Adding an ignore rule
  previously meant leaving the editor to hand-edit the file.
- The bottom dock toolbar now has a username field with Log In / Log Out buttons wired
  to `FxvRunner.login()` / `logout()`, which previously had no UI entry point at all —
  authenticating required a separate terminal running `fxv login <username>`.
- The History tab's revision list now has a details panel below it: selecting a revision
  loads and lists the files it changed (path, action, size) via the CLI's `changeinfo`
  command, with results cached per revision. `FxvRunner.get_change_info()` and
  `FxvDto.ChangeInfoPayload` already existed and were fully tested, but no UI called them.
- **Project > Tools** now includes FlexVault actions that act on whatever is currently
  selected in the FileSystem dock: Revert Selection, Diff Selection Against Base,
  Resolve Selection (Mine), and Resolve Selection (Theirs). `FxvContextMenu` previously
  declared a `register_actions()` entry point that was never called and did nothing.
  Godot's FileSystemDock has no supported API for adding entries to its native
  right-click menu before Godot 4.3's `EditorContextMenuPlugin`, so these are exposed as
  Tools menu items acting on the current dock selection instead.
- New Editor Settings option, **Version Control > FlexVault > Timeout Seconds**
  (default `0`, disabled). When set above zero, an async CLI call that exceeds it is
  reported back to the caller as timed out instead of leaving the dock waiting
  indefinitely.

### Changed
- `FxvRunner` now executes the `fxv` CLI on a background `Thread` for every dock and menu
  action (`run_command_async` plus per-command async wrappers), so Snapshot, Publish,
  Sync, Goto, Revert, and Resolve no longer freeze the Godot editor while the CLI process
  runs. The bottom dock disables its action buttons for the duration of an in-flight
  operation instead.

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
