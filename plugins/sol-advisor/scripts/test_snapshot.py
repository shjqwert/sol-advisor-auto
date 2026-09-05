"""Real Git regression for gitlink, checkout and submodule worktree protection."""
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

MODULE = runpy.run_path(str(Path(__file__).with_name("prepare-repo-search.py")))
SNAPSHOT = MODULE["git_change_snapshot"]


class SubmoduleSnapshotTests(unittest.TestCase):
    def git(self, root, *args):
        return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.STDOUT).decode().strip()

    def test_gitlink_checkout_content_and_untracked_changes(self):
        with tempfile.TemporaryDirectory(prefix="advisor-submodule-") as tmp:
            root = Path(tmp) / "parent"
            source = Path(tmp) / "source"
            for repo in (root, source):
                repo.mkdir()
                self.git(repo, "init", "-q")
                self.git(repo, "config", "user.email", "test@example.invalid")
                self.git(repo, "config", "user.name", "Test")
            (source / "code.c").write_text("one")
            self.git(source, "add", ".")
            self.git(source, "commit", "-qm", "first")
            first = self.git(source, "rev-parse", "HEAD")
            (source / "code.c").write_text("two")
            self.git(source, "commit", "-qam", "second")
            second = self.git(source, "rev-parse", "HEAD")
            self.git(root, "-c", "protocol.file.allow=always", "submodule", "add", str(source), "module")
            self.git(root, "commit", "-qam", "add module")
            child = root / "module"
            before = SNAPSHOT(root)
            (child / "code.c").write_text("dirty")
            self.assertNotEqual(before[1], SNAPSHOT(root)[1])
            (child / "code.c").write_text("dirty again")
            dirty = SNAPSHOT(root)
            (child / "code.c").write_text("another dirty value")
            self.assertNotEqual(dirty[1], SNAPSHOT(root)[1])
            self.git(child, "checkout", "--", "code.c")
            (child / "new.c").write_text("new")
            self.assertIn("module/new.c", SNAPSHOT(root)[0])
            (child / "new.c").unlink()
            self.git(child, "checkout", "-q", first)
            self.assertNotEqual(before[1], SNAPSHOT(root)[1])
            self.git(child, "checkout", "-q", second)
            self.assertEqual(before, SNAPSHOT(root))
            self.git(root, "update-index", "--cacheinfo", f"160000,{first},module")
            self.assertNotEqual(before[1], SNAPSHOT(root)[1])
            self.git(root, "update-index", "--cacheinfo", f"160000,{second},module")
            self.git(root, "submodule", "deinit", "-f", "module")
            with self.assertRaises(MODULE["SnapshotError"]):
                SNAPSHOT(root)

    def test_failed_git_index_is_not_unchanged(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.git(root, "init", "-q")
            real_run = SNAPSHOT.__globals__["run"]
            def failing(command, **kwargs):
                if "--stage" in command:
                    return subprocess.CompletedProcess(command, 1, "", "unreadable index")
                return real_run(command, **kwargs)
            with patch.dict(SNAPSHOT.__globals__, run=failing):
                with self.assertRaises(MODULE["SnapshotError"]):
                    SNAPSHOT(root)


if __name__ == "__main__":
    unittest.main()
