# CHANGELOG

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
