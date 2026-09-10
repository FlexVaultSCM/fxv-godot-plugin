@tool
class_name FxvSafetyGuards
extends RefCounted

## Validates editor safety states before mutating workspace files.

static func ensure_safe_to_mutate(operation_name: String, save_scenes: bool = true) -> bool:
	# 1. Check if game is running in editor
	if EditorInterface.is_playing_scene():
		push_error("[FlexVault] %s blocked: Cannot perform operation while game is playing in editor." % operation_name)
		return false

	# 2. Save modified scenes if requested
	if save_scenes:
		EditorInterface.save_all_scenes()

	return true
