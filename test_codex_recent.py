import sqlite3
import tempfile
import time
import unittest
from pathlib import Path

from codex_recent import load_projects


class LoadProjectsTest(unittest.TestCase):
    def test_groups_recent_user_threads_by_project(self):
        with tempfile.TemporaryDirectory() as directory:
            db = Path(directory) / "state_5.sqlite"
            connection = sqlite3.connect(db)
            connection.execute(
                """CREATE TABLE threads (
                    id TEXT, cwd TEXT, name TEXT, title TEXT, first_user_message TEXT,
                    recency_at INTEGER, archived INTEGER, thread_source TEXT
                )"""
            )
            now = int(time.time())
            connection.executemany(
                "INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    ("new", "/tmp/alpha", "Latest", "", "", now, 0, "user"),
                    ("older", "/tmp/alpha", "Older", "", "", now - 60, 0, "user"),
                    ("worker", "/tmp/beta", "Worker", "", "", now, 0, "subagent"),
                    ("stale", "/tmp/gamma", "Stale", "", "", now - 90000, 0, "user"),
                ],
            )
            connection.commit()
            connection.close()

            projects = load_projects(db, 24)

        self.assertEqual([project["name"] for project in projects], ["alpha"])
        self.assertEqual(projects[0]["latest_thread_id"], "new")
        self.assertEqual(len(projects[0]["threads"]), 2)


if __name__ == "__main__":
    unittest.main()
