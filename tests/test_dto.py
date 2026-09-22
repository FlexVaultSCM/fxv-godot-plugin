import json
import unittest

sample_status_json = """{
    "program": {
        "name": "fxv",
        "version": "0.8.0",
        "executable": "fxv.exe",
        "arguments": ["status", "--format", "json"],
        "invoked_at": "2026-09-10T12:00:00Z"
    },
    "message": {
        "kind": "status",
        "version": "1.0",
        "payload": {
            "current_branch": "main",
            "current_user": "alice",
            "head_commit": {
                "state": "clean",
                "branch": "main",
                "local_snapshot": {
                    "commit": {
                        "branch": "main",
                        "revision": 3,
                        "type": "published"
                    },
                    "commit_hash": "c0ffee1234",
                    "description": "Added godot project",
                    "timestamp_millis_since_epoch_utc": 1774328905000,
                    "author_id": "alice",
                    "author_display_name": "Alice Developer"
                }
            },
            "sync_status": {
                "up_to_date": true,
                "revisions_behind": 0,
                "published_head_revision": 3,
                "synced_revision": 3
            },
            "files": [
                {
                    "path": "scenes/main.tscn",
                    "workspace_state": "modified",
                    "size": 4096
                },
                {
                    "path": "scripts/player.gd",
                    "workspace_state": "added",
                    "size": 1024
                },
                {
                    "path": "assets/enemy.png",
                    "workspace_state": "conflicted",
                    "size": 65536
                }
            ],
            "file_change_counts": {
                "total": 3,
                "unpublished": 0,
                "workspace_need_snapshot": 3
            }
        }
    }
}"""

class TestDtoParsing(unittest.TestCase):
    def test_parse_status_payload(self):
        data = json.loads(sample_status_json)
        msg = data["message"]
        self.assertEqual(msg["kind"], "status")
        payload = msg["payload"]
        self.assertEqual(payload["current_branch"], "main")
        self.assertEqual(payload["current_user"], "alice")
        self.assertEqual(len(payload["files"]), 3)
        self.assertEqual(payload["files"][0]["workspace_state"], "modified")
        self.assertEqual(payload["files"][2]["workspace_state"], "conflicted")

    def test_parse_branch_list_payload(self):
        sample_branch_list_json = """{
            "program": {
                "name": "fxv",
                "version": "0.11.0",
                "executable": "fxv.exe",
                "arguments": ["branch", "list", "--format", "json"],
                "invoked_at": "2026-09-22T12:00:00Z"
            },
            "message": {
                "kind": "branch-list",
                "version": "1.0",
                "payload": {
                    "branches": [
                        {
                            "branch": "main",
                            "branch_unique_id": "0123456789abcdef",
                            "branch_type": "global",
                            "published_head": "main.10",
                            "draft_head": "main.10.1",
                            "local_only": false,
                            "retired": false
                        },
                        {
                            "branch": "alice/feature",
                            "branch_unique_id": "fedcba9876543210",
                            "branch_type": "user",
                            "owner": "alice",
                            "draft_head": "alice/feature.-.1",
                            "local_only": true,
                            "retired": false
                        }
                    ]
                }
            }
        }"""
        data = json.loads(sample_branch_list_json)
        msg = data["message"]
        self.assertEqual(msg["kind"], "branch-list")
        payload = msg["payload"]
        self.assertEqual(len(payload["branches"]), 2)
        b0 = payload["branches"][0]
        self.assertEqual(b0["branch"], "main")
        self.assertEqual(b0["branch_type"], "global")
        self.assertEqual(b0["published_head"], "main.10")
        b1 = payload["branches"][1]
        self.assertEqual(b1["branch"], "alice/feature")
        self.assertEqual(b1["branch_type"], "user")
        self.assertEqual(b1["owner"], "alice")
        self.assertTrue(b1["local_only"])

if __name__ == "__main__":
    unittest.main()

