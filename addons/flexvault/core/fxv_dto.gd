@tool
class_name FxvDto
extends RefCounted

## Data Transfer Objects mirroring fxv CLI JSON schema.

class ProgramMetadata extends RefCounted:
	var name: String = ""
	var version: String = ""
	var executable: String = ""
	var arguments: Array = []
	var invoked_at: String = ""

	static func from_dict(d: Dictionary) -> ProgramMetadata:
		var p := ProgramMetadata.new()
		if d.is_empty(): return p
		p.name = d.get("name", "")
		p.version = d.get("version", "")
		p.executable = d.get("executable", "")
		p.arguments = d.get("arguments", [])
		p.invoked_at = d.get("invoked_at", "")
		return p


class FileStatusItem extends RefCounted:
	var path: String = ""
	var unpublished_state: String = ""
	var workspace_state: String = ""
	var conflict_state: Variant = null
	var size: int = 0

	var is_conflicted: bool:
		get:
			return conflict_state != null or \
				workspace_state.to_lower() == "conflicted" or \
				unpublished_state.to_lower() == "conflicted"

	var needs_snapshot: bool:
		get:
			return not workspace_state.is_empty() and workspace_state.to_lower() != "unchanged"

	var is_unpublished: bool:
		get:
			return not unpublished_state.is_empty() and unpublished_state.to_lower() != "unchanged"

	var effective_workspace_state: String:
		get:
			if is_conflicted:
				return "conflicted"
			if not workspace_state.is_empty() and workspace_state.to_lower() != "unchanged":
				if workspace_state.to_lower() == "maybe_changed":
					return "modified"
				return workspace_state.to_lower()
			return "unchanged"

	var effective_state: String:
		get:
			if is_conflicted:
				return "conflicted"
			if not workspace_state.is_empty() and workspace_state.to_lower() != "unchanged":
				if workspace_state.to_lower() == "maybe_changed":
					return "modified"
				return workspace_state.to_lower()
			if not unpublished_state.is_empty() and unpublished_state.to_lower() != "unchanged":
				return unpublished_state.to_lower()
			return "unchanged"

	static func from_dict(d: Dictionary) -> FileStatusItem:
		var item := FileStatusItem.new()
		item.path = d.get("path", "")
		item.unpublished_state = d.get("unpublished_state", "")
		item.workspace_state = d.get("workspace_state", "")
		item.conflict_state = d.get("conflict_state", null)
		item.size = int(d.get("size", 0))
		return item


class CommitInfoDetail extends RefCounted:
	var branch: String = ""
	var revision: Variant = null
	var type: String = ""
	var draft_revision: Variant = null

	static func from_dict(d: Dictionary) -> CommitInfoDetail:
		var c := CommitInfoDetail.new()
		if d.is_empty(): return c
		c.branch = d.get("branch", "")
		# JSON.parse_string() decodes every number as float, so an un-cast float(0) renders as
		# "0.0" via str() and corrupts compound revision strings like "main.0.2" into
		# "main.0.0.2.0". Cast to int here so revision_display always formats cleanly.
		c.revision = int(d["revision"]) if d.get("revision") != null else null
		c.type = d.get("type", "")
		c.draft_revision = int(d["draft_revision"]) if d.get("draft_revision") != null else null
		return c


class CommitRef extends RefCounted:
	var commit: CommitInfoDetail = null
	var commit_hash: String = ""
	var description: String = ""
	var timestamp_millis: int = 0
	var author_id: String = ""
	var author_display_name: String = ""

	var revision_display: String:
		get:
			if commit == null:
				return "unknown"
			# draft_revision == 0 means the workspace snapshot has no draft changes beyond the
			# published head, so it displays the same as the published revision (e.g. "main.1"),
			# not with a spurious ".0" draft suffix that won't match the published entry's own
			# revision_display (used to detect the current row in the History tab).
			if commit.type == "draft" and commit.draft_revision != null and int(commit.draft_revision) > 0:
				if commit.revision != null:
					return "%s.%s.%s" % [commit.branch, str(commit.revision), str(commit.draft_revision)]
				else:
					return "%s.-.%s" % [commit.branch, str(commit.draft_revision)]
			if commit.revision != null:
				return "%s.%s" % [commit.branch, str(commit.revision)]
			return commit.branch

	static func from_dict(d: Dictionary) -> CommitRef:
		var cr := CommitRef.new()
		if d.is_empty(): return cr
		cr.commit = CommitInfoDetail.from_dict(d.get("commit", {}))
		cr.commit_hash = d.get("commit_hash", "")
		cr.description = d.get("description", "")
		cr.timestamp_millis = int(d.get("timestamp_millis_since_epoch_utc", 0))
		cr.author_id = d.get("author_id", "")
		cr.author_display_name = d.get("author_display_name", "")
		return cr


class HeadCommit extends RefCounted:
	var state: String = ""
	var branch: String = ""
	var local_snapshot: CommitRef = null
	var published_head: CommitRef = null

	static func from_dict(d: Dictionary) -> HeadCommit:
		var hc := HeadCommit.new()
		if d.is_empty(): return hc
		hc.state = d.get("state", "")
		hc.branch = d.get("branch", "")
		if d.has("local_snapshot") and d["local_snapshot"] is Dictionary:
			hc.local_snapshot = CommitRef.from_dict(d["local_snapshot"])
		if d.has("published_head") and d["published_head"] is Dictionary:
			hc.published_head = CommitRef.from_dict(d["published_head"])
		return hc


class SyncStatus extends RefCounted:
	var up_to_date: bool = true
	var revisions_behind: int = 0
	var published_head_revision: int = 0
	var synced_revision: Variant = null

	static func from_dict(d: Dictionary) -> SyncStatus:
		var ss := SyncStatus.new()
		if d.is_empty(): return ss
		ss.up_to_date = bool(d.get("up_to_date", true))
		ss.revisions_behind = int(d.get("revisions_behind", 0))
		ss.published_head_revision = int(d.get("published_head_revision", 0))
		ss.synced_revision = int(d["synced_revision"]) if d.get("synced_revision") != null else null
		return ss


class StatusPayload extends RefCounted:
	var current_branch: String = ""
	var current_user: String = ""
	var head_commit: HeadCommit = null
	var sync_status: SyncStatus = null
	var files: Array[FileStatusItem] = []
	var total_changes: int = 0
	var unpublished_changes: int = 0
	var workspace_changes_count: int = 0
	var head_revision_display: String:
		get:
			if head_commit == null:
				return "-"
			if head_commit.local_snapshot != null:
				return head_commit.local_snapshot.revision_display
			if head_commit.published_head != null:
				return head_commit.published_head.revision_display
			if not head_commit.branch.is_empty():
				return head_commit.branch
			return "-"

	static func from_dict(d: Dictionary) -> StatusPayload:
		var sp := StatusPayload.new()
		if d.is_empty(): return sp
		sp.current_branch = d.get("current_branch", "")
		sp.current_user = d.get("current_user", "")
		if d.has("head_commit") and d["head_commit"] is Dictionary:
			sp.head_commit = HeadCommit.from_dict(d["head_commit"])
		if d.has("sync_status") and d["sync_status"] is Dictionary:
			sp.sync_status = SyncStatus.from_dict(d["sync_status"])

		if d.has("files") and d["files"] is Array:
			for f in d["files"]:
				if f is Dictionary:
					sp.files.append(FileStatusItem.from_dict(f))

		var counts: Dictionary = d.get("file_change_counts", {})
		sp.total_changes = int(counts.get("total", 0))
		sp.unpublished_changes = int(counts.get("unpublished", 0))
		sp.workspace_changes_count = int(counts.get("workspace_need_snapshot", 0))
		return sp


class WorkspaceSyncPayload extends RefCounted:
	var target_revision: String = ""
	var files_updated_count: int = 0
	var error_count: int = 0
	var files_updated: Array[FileStatusItem] = []
	var conflicted_files: Array[String] = []

	static func from_dict(d: Dictionary) -> WorkspaceSyncPayload:
		var wsp := WorkspaceSyncPayload.new()
		if d.is_empty(): return wsp
		wsp.target_revision = d.get("target_revision", "")
		wsp.files_updated_count = int(d.get("files_updated_count", 0))
		wsp.error_count = int(d.get("error_count", 0))
		if d.has("files_updated") and d["files_updated"] is Array:
			for f in d["files_updated"]:
				if f is Dictionary:
					wsp.files_updated.append(FileStatusItem.from_dict(f))
		if d.has("conflicted_files") and d["conflicted_files"] is Array:
			for cf in d["conflicted_files"]:
				wsp.conflicted_files.append(str(cf))
		return wsp


class HistoryPayload extends RefCounted:
	var entries: Array[CommitRef] = []

	static func from_dict(d: Dictionary) -> HistoryPayload:
		var hp := HistoryPayload.new()
		if d.is_empty(): return hp
		if d.has("entries") and d["entries"] is Array:
			for e in d["entries"]:
				if e is Dictionary:
					hp.entries.append(CommitRef.from_dict(e))
		return hp


class ChangeInfoItem extends RefCounted:
	var path: String = ""
	var action: String = ""
	var size: int = 0
	var old_hash: String = ""
	var new_hash: String = ""

	static func from_dict(d: Dictionary) -> ChangeInfoItem:
		var cii := ChangeInfoItem.new()
		if d.is_empty(): return cii
		cii.path = d.get("path", "")
		cii.action = d.get("action", "")
		cii.size = int(d.get("size", 0))
		cii.old_hash = d.get("old_hash", "")
		cii.new_hash = d.get("new_hash", "")
		return cii


class ChangeInfoPayload extends RefCounted:
	var commit: CommitInfoDetail = null
	var commit_hash: String = ""
	var description: String = ""
	var timestamp_millis: int = 0
	var author_id: String = ""
	var author_display_name: String = ""
	var changes: Array[ChangeInfoItem] = []

	static func from_dict(d: Dictionary) -> ChangeInfoPayload:
		var cip := ChangeInfoPayload.new()
		if d.is_empty(): return cip
		cip.commit = CommitInfoDetail.from_dict(d.get("commit", {}))
		cip.commit_hash = d.get("commit_hash", "")
		cip.description = d.get("description", "")
		cip.timestamp_millis = int(d.get("timestamp_millis_since_epoch_utc", 0))
		cip.author_id = d.get("author_id", "")
		cip.author_display_name = d.get("author_display_name", "")
		if d.has("changes") and d["changes"] is Array:
			for ch in d["changes"]:
				if ch is Dictionary:
					cip.changes.append(ChangeInfoItem.from_dict(ch))
		return cip
