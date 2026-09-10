# FlexVault Godot Plugin (`fxv-godot-plugin`)

Godot Engine 4.x Editor Version Control plugin for [FlexVault](https://fxv.dev). Integrates the `fxv` CLI directly into the Godot Editor.

---

## Requirements

* **Godot**: Godot 4.0, 4.1, 4.2, 4.3+.
* **FlexVault CLI**: `fxv` binary version `0.5.0` to `< 0.10.0` installed and accessible (or configured via Editor Settings).

---

## Installation

### Option 1: Release Archive
1. Download the latest release `.zip` (`fxv-godot-plugin.zip`) from [GitHub Releases](https://github.com/FlexVaultSCM/fxv-godot-plugin/releases).
2. Extract the `addons/flexvault/` folder into your Godot project's root `addons/` directory:
   ```text
   res://
   └── addons/
       └── flexvault/
           ├── plugin.cfg
           ├── flexvault_plugin.gd
           ├── core/
           └── ui/
   ```
3. In the Godot Editor, open **Project -> Project Settings -> Plugins** and check **Enable** for FlexVault.

---

## Configuration

Settings can be customized in **Editor -> Editor Settings -> Version Control -> FlexVault**:
* **CLI Executable Path**: Set a custom path to `fxv.exe` (Windows) or `fxv` (Linux/macOS), or rely on auto-discovery from standard paths and `PATH`.
* **Diff Tool**: Set a custom visual diff utility (or rely on `FXV_DIFF_TOOL` / `DIFF` environment variables or auto-detection of VS Code, Beyond Compare, KDiff3, etc.).

---

## Features

* **Dockable Bottom Panel ("FlexVault")**:
  * **Changes View**: Displays all modified, added, deleted, and conflicted files with color-coded status badges and file sizes.
  * **Draft Snapshotting**: Create local checkpoints (`fxv snapshot`) with a description without publishing to remote.
  * **Publishing**: Publish your local draft changes to the central repository (`fxv publish`).
  * **Revert**: Revert selected files and their companion Godot `.import` and `.uid` metadata files back to their published base state.
  * **Diff Support**: Diff modified files against their published or local snapshot base revision in an external visual diff viewer.
  * **Conflict Resolution**: Inline `[Resolve (Mine)]` and `[Resolve (Theirs)]` actions for merge conflict resolution.
  * **Workspace Synchronization**: One-click synchronization (`fxv sync`) to pull latest revisions from remote and rebase local drafts.
  * **History & Revision Jumping**: Browse repository commit history (revisions, authors, commit descriptions, commit hashes) and jump to any historical revision (`fxv goto`).
* **Companion File Atomicity**:
  * Automatically coordinates Godot engine companion files (`.import` and `.uid`) whenever files are reverted or resolved to prevent broken resource links.
* **Mutation Safety Guards**:
  * Blocks mutating operations when a scene is running in the editor.
  * Automatically saves open scenes before workspace file mutations.

---

## Feedback & Support

Bug reports and feedback are welcome on the [FlexVault Discord](https://discord.gg/KCMHRQBDf).
For documentation, see [docs.fxv.dev](https://docs.fxv.dev).
