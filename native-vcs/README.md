# FlexVault native VCS extension

A GDExtension that implements Godot's `EditorVCSInterface`, so a FlexVault workspace shows up
in **Project > Version Control > Version Control Settings** instead of the editor's "No VCS
plugins are available" dialog. This is separate from the `addons/flexvault` GDScript plugin
(bottom dock, tool menu, context menu) - Godot only offers that dialog's integration to
classes that extend the native `EditorVCSInterface`, which isn't reachable from GDScript.

It's a thin bridge: every call shells out to the `fxv` CLI and reuses the same JSON envelope
`addons/flexvault/core/fxv_runner.gd` parses, so both integrations report identical state.
FlexVault has no git-style staging area - every pending change ships with the next
`fxv snapshot` - so `_get_modified_files_data()` reports everything as already staged, and
stage/unstage are no-ops. Per-commit history diffs aren't implemented yet, only the live
working-tree diff.

## Building

Requires a C++17 toolchain and [SCons](https://scons.org/). godot-cpp is a submodule pinned to
its `4.1` branch (the minimum Godot version this extension supports):

```sh
git submodule update --init --recursive
cd native-vcs
scons platform=<windows|linux|macos> target=template_debug   # or template_release
```

The build writes `addons/flexvault_vcs/bin/libfxv_vcs.<platform>.<target>.<arch>{.dll,.so}` (a
`.framework` bundle on macOS), which `addons/flexvault_vcs/flexvault_vcs.gdextension` already
points at. CI builds all three platforms on every PR (see `.github/workflows/ci.yml`); the
compiled binaries themselves aren't committed to the repo.
