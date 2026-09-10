# CHANGELOG

## [Unreleased]

### Fixed
- Clicking **Publish** with no local snapshot taken (and no prior unpublished draft) no
  longer reports "Published successfully." while actually doing nothing. `fxv publish` only
  publishes committed draft snapshots, not raw workspace edits, and exits 0 whether or not
  there was anything to publish; `snapshot`/`publish` also don't support `--format json`, so
  there was no payload to tell the two cases apart. The dock now checks the cached status
  first and reports "Nothing to publish." (or, if there are unsnapshotted workspace changes,
  a hint to snapshot first) instead of calling the CLI.

### Added
- The toolbar now shows an animated loading spinner next to the status label whenever a CLI
  operation is in flight, cycling the editor theme's built-in `Progress1`..`Progress8`
  icons (the same frames the native editor uses for its own loading indicators) on a
  0.08s timer. Previously the only busy indicator was the disabled action buttons, easy to
  miss, especially for fast operations.
- The status header now shows an unpublished change count (e.g. "3 unpublished changes")
  whenever the workspace has snapshotted files that haven't been published yet, and their
  rows in the Changes tab are marked "(unpublished)". A snapshotted file previously showed
  the same status text as any other pending change, so there was no way to tell from the
  dock that Snapshot had already run and only Publish remained.

### Changed
- The History tab's revision list / changed-files detail split now actually starts at 50%
  height, for the same reason as the Changes tab split below: `details_container` had a
  100px minimum but no `SIZE_EXPAND_FILL`, so the revision list claimed all the extra
  height by default and the detail panel stayed pinned to its 100px floor.
- The Changes tab's tree/description split now actually starts at 50% width. The
  description panel (`commit_panel`) was missing `SIZE_EXPAND_FILL`, so Godot's default
  split position already gave it just its 240px minimum; the previous fix tried to correct
  this by setting `split_offset` to half the container's width on every resize, but
  `split_offset` is a delta added on top of that default position, not an absolute pixel
  coordinate, so it pushed the divider off past the visible width and had no visible effect.
  Fixed by giving both sides `SIZE_EXPAND_FILL` so Godot's own default split is 50/50; the
  per-resize recentering hack is no longer needed and has been removed.
- Removed the bottom dock's **Log Out** button. It's a rare, deliberate action that doesn't
  belong next to the common toolbar actions where it's easy to click by accident; use
  `fxv logout` directly if you need to switch users. `FxvRunner.logout()` /
  `logout_async()` are unchanged for anything that still wants to call them
  programmatically.

### Changed
- The Changes tab's **Diff Base** button is renamed to **Diff Against Previous**, matching
  the naming of the two new History tab diff buttons below. Behavior is unchanged: it still
  diffs a selected pending file against its local snapshot or published head, whichever is
  the more recent base.

### Added
- The History tab's changed-files detail panel now has **Diff Against Current** and **Diff
  Against Previous** buttons, enabled when a file is selected there. Against Current opens
  the same diff viewer as the Changes tab's Diff Against Previous, comparing the file as of the selected
  revision against the live workspace copy; Against Previous fetches the file as of the
  selected revision and as of the next-older revision in the loaded history list and diffs
  those against each other via a new `FxvDiffHelper.diff_file_between_revisions()`. Both
  report "no differences" instead of opening an empty diff when the two sides hash
  identically, same as Diff Against Previous.

### Changed
- The History tab's **Switch to Revision (Goto)** button is now disabled until a revision
  is selected in the history list, instead of being always-clickable and silently no-op'ing
  when nothing was selected. Same pattern already used for the Changes tab's Diff Against
  Previous and Revert Selected buttons.

### Added
- The toolbar's **Sync Workspace** button now shows the revs-behind count (e.g. "Sync
  Workspace (2 revs behind)") and highlights in orange whenever the published branch has
  changes the workspace hasn't pulled yet. Previously the only indicator was the smaller
  "(N revs behind)" text tucked into the branch/user label, easy to miss.

### Changed
- Removed the toolbar's **Refresh** button. Status already auto-refreshes on a 10s poll and
  on a debounced watch of Godot's resource filesystem, so it was almost always redundant;
  the History tab keeps its own **Refresh History** button, which still has no automatic
  equivalent.

### Fixed
- The Changes tab, History tab, and the History tab's changed-files detail panel no longer
  show a stray collapse/expand arrow above their first row. Each tree's hidden root item was
  never marked hidden (`hide_root` was left at its default `false`), so Godot rendered it as
  its own foldable row on top of the real, flat list of files/revisions. `hide_root` is now
  set on all three trees.
- The status header showed the workspace head as `main.1.0` while the History tab listed
  the same commit as `main.1`, so the History tab never highlighted it as the current
  revision. `CommitRef.revision_display` appended a `.0` draft suffix whenever a commit's
  type was `draft`, even when `draft_revision` was `0` (meaning no draft snapshot exists
  beyond the published head). It now only appends the suffix when `draft_revision > 0`, so
  a workspace in sync with its published head displays and matches the same revision
  string everywhere.
- **Diff Base** no longer launches the external diff tool for a file that has no actual
  content differences against its base revision (e.g. a file flagged `maybe_changed` by a
  timestamp-only touch, or otherwise byte-identical to its base). The base revision is now
  hashed against the working copy first; on a match, the status bar reports "no differences"
  instead of opening an empty/no-op diff window. Applies to both the Changes tab button and
  the Tools > FlexVault: Diff Selection Against Base menu item.

### Changed
- The Changes tab's **Diff Base** and **Revert Selected** buttons are now disabled until at
  least one file is selected in the changes tree, instead of being always-clickable and
  silently no-op'ing (or, for Revert, popping a confirmation dialog for a revert that
  affects nothing) when nothing was selected.

### Fixed
- Snapshot, Publish, Sync, Login, Logout, Revert, and Resolve now show the real CLI error
  message in the bottom dock's status bar on failure, instead of a generic "X failed."
  with the actual reason only visible in the console via `push_error`. Same class of bug
  already fixed for Goto and the History tab's changeinfo lookups.

### Fixed
- The History tab no longer refuses to load changed files for an unparented local draft
  (a draft with no published parent, revision spec `main.-.N`). The check for this case
  assumed the CLI reports it as revision `-1`, which never happens — the wire format omits
  the `revision` key entirely for it — so the check was unreachable dead code, and the
  premise behind it was wrong: `fxv changeinfo` already handles `main.-.N` correctly,
  returning every file as "added" against the empty base. Verified directly against the
  real CLI. Removed the special case; the normal changeinfo round trip now runs for this
  case like any other.
- Selecting a draft revision in the History tab (e.g. `main.0.2`, a draft with a published
  parent) no longer fails changeinfo lookups with errors like "Invalid branch revision
  number: 0.2.0". `JSON.parse_string()` decodes every JSON number as a Godot `float`, and
  `CommitInfoDetail.revision`/`draft_revision` (and `SyncStatus.synced_revision`) kept that
  raw float instead of casting to `int`. Formatting a whole-number float with `str()`
  appends a trailing `.0`, so a revision string like `main.0.2` was actually being sent to
  the CLI as `main.0.0.2.0`, which fails to parse. Both DTOs now cast these fields to `int`
  on load.
- The History tab no longer flickers and drops its selection during routine background
  status refreshes (the 10s poll, or the new debounced filesystem-change refresh).
  Every status update was unconditionally clearing and rebuilding the whole history tree
  whenever the History tab was open, discarding the current selection and its loaded
  change-info detail. It now only reloads when the workspace head has actually moved
  since the last load, and re-selects the previously selected revision (restoring its
  cached change-info instantly) when it does reload.
- History row selection no longer discards the actual `changeinfo` failure reason behind
  a generic "Failed to load changed files" message. The History tab also no longer
  attempts `changeinfo` for a row that is an unpublished local draft with no prior
  published revision to diff against (revision `-1`, e.g. the very first snapshot on a
  branch before anything has been published) — that case surfaced as a confusing
  "Failed to load changed files for main.-1.0" with no explanation.

### Added
- Status now refreshes immediately (debounced 0.3s) when Godot's resource filesystem
  reports a change (asset imported, moved, or deleted), instead of only on the fixed
  10-second poll timer. The poll timer stays as a fallback for changes the filesystem
  watcher doesn't catch, e.g. remote-side updates.
- New Editor Settings option, **Version Control > FlexVault > Default Resolve
  Preference** (Ask Each Time / Keep Mine / Take Theirs; default Ask Each Time). When set
  to Mine or Theirs, a Sync that produces conflicts resolves them automatically instead
  of always requiring a manual per-file choice.
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
