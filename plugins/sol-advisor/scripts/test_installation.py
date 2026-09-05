from pathlib import Path
import os
import runpy
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout
import io
import json

SCRIPT = Path(__file__).resolve().parent
SOURCE = SCRIPT.parent
CHECK = runpy.run_path(str(SCRIPT / "check-installation.py"))["check_installation"]


class InstallationTests(unittest.TestCase):
    def test_seven_role_upgrade_removal_and_rollback(self):
        shell = shutil.which("sh")
        if not shell:
            self.skipTest("POSIX shell unavailable")
        for ending in ("lf", "crlf"):
            with self.subTest(ending=ending), tempfile.TemporaryDirectory(prefix="sol-seven-upgrade-") as tmp:
                target = Path(tmp) / "agents"
                shutil.copytree(SCRIPT / "fixtures/agents-1.0.0-seven", target)
                if ending == "crlf":
                    for file in target.glob("*.toml"):
                        file.write_bytes(file.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
                command = [shell, str(SCRIPT / "install-agents.sh"), "--target-dir", str(target), "--upgrade-managed"]
                retired = target / "sol-advisor-test-executor.toml"
                original = retired.read_bytes()
                retired.write_bytes(original + b"\n# user modification\n")
                before = {p.name: p.read_bytes() for p in target.glob("*.toml")}
                self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
                self.assertEqual(before, {p.name: p.read_bytes() for p in target.glob("*.toml")})
                retired.write_bytes(original)
                before = {p.name: p.read_bytes() for p in target.glob("*.toml")}
                # Fail after the first retired role is removed, including prior upgrades.
                changed = sum(before[p.name] != p.read_bytes() for p in (SOURCE / "agents").glob("*.toml"))
                result = subprocess.run(command, capture_output=True, env={**os.environ,
                    "SOL_ADVISOR_INSTALL_TEST_FAIL_AFTER": str(changed + 1)})
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(before, {p.name: p.read_bytes() for p in target.glob("*.toml")})
                result = subprocess.run(command, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                self.assertEqual({p.name for p in target.glob("*.toml")}, {p.name for p in (SOURCE / "agents").glob("*.toml")})

    def test_registration_uses_the_selected_codex_home(self):
        module = runpy.run_path(str(SCRIPT / "check-installation.py"))
        version = json.loads((SOURCE / ".codex-plugin/plugin.json").read_text(encoding="utf-8"))["version"]
        with tempfile.TemporaryDirectory(prefix="sol-registration-check-") as tmp:
            root = Path(tmp)
            cache = root / "plugins/cache/sol-advisor/sol-advisor" / version
            shutil.copytree(SOURCE, cache, ignore=shutil.ignore_patterns("__pycache__"))
            shutil.copytree(SOURCE / "agents", root / "agents")
            listing = json.dumps({"installed": [{"pluginId": "sol-advisor@sol-advisor", "version": version, "enabled": True}]})
            with patch("sys.argv", ["check-installation.py", "--source", str(SOURCE), "--codex-home", str(root)]), \
                 patch("shutil.which", return_value="codex.cmd"), \
                 patch("subprocess.check_output", return_value=listing) as call, redirect_stdout(io.StringIO()):
                with self.assertRaises(SystemExit) as result:
                    module["main"]()
                self.assertEqual(result.exception.code, 0)
                self.assertEqual(call.call_args.kwargs["env"]["CODEX_HOME"], str(root.resolve()))

    def test_cache_and_native_agents_are_independently_checked(self):
        with tempfile.TemporaryDirectory(prefix="sol-install-check-") as tmp:
            root = Path(tmp)
            cache, agents = root / "cache", root / "agents"
            shutil.copytree(SOURCE, cache, ignore=shutil.ignore_patterns("__pycache__"))
            shutil.copytree(SOURCE / "agents", agents)
            self.assertTrue(CHECK(SOURCE, cache, agents)["ok"])
            file = agents / "sol-advisor-context-analyst.toml"
            file.write_text("user customization", encoding="utf-8")
            before = file.read_bytes()
            self.assertIn({"surface": "native-agent", "file": file.name}, CHECK(SOURCE, cache, agents)["differences"])
            self.assertEqual(file.read_bytes(), before)
            (cache / "skills/orchestration/SKILL.md").write_text("stale skill", encoding="utf-8")
            (cache / "retired.py").write_text("retired", encoding="utf-8")
            self.assertEqual({p["surface"] for p in CHECK(SOURCE, cache, agents)["differences"]}, {"native-agent", "plugin-cache", "extra-cache-file"})

    def test_known_2932669_upgrade_and_modified_template_refusal(self):
        shell = shutil.which("sh")
        if not shell:
            self.skipTest("POSIX shell unavailable")
        for ending in ("lf", "crlf"):
            with self.subTest(ending=ending), tempfile.TemporaryDirectory(prefix="sol-legacy-check-") as tmp:
                target = Path(tmp) / "agents"
                shutil.copytree(SCRIPT / "fixtures/agents-2932669", target)
                if ending == "crlf":
                    for file in target.glob("*.toml"):
                        file.write_bytes(file.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
                command = [shell, str(SCRIPT / "install-agents.sh"), "--target-dir", str(target), "--upgrade-managed"]
                failed_file = target / "sol-advisor-investigator.toml"
                original = failed_file.read_bytes()
                failed_file.write_bytes(original + b"\n# user modification\n")
                before = {f.name: f.read_bytes() for f in target.glob("*.toml")}
                result = subprocess.run(command, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(before, {f.name: f.read_bytes() for f in target.glob("*.toml")})
                failed_file.write_bytes(original)
                before = {f.name: f.read_bytes() for f in target.glob("*.toml")}
                rollback = subprocess.run(command, capture_output=True, env={**os.environ, "SOL_ADVISOR_INSTALL_TEST_FAIL_AFTER": "2"})
                self.assertNotEqual(rollback.returncode, 0)
                self.assertEqual(before, {f.name: f.read_bytes() for f in target.glob("*.toml")})
                result = subprocess.run(command, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                self.assertEqual(len(list(target.glob("*.toml"))), 5)
                for file in (SOURCE / "agents").glob("*.toml"):
                    self.assertEqual(file.read_bytes(), (target / file.name).read_bytes())


if __name__ == "__main__":
    unittest.main()
