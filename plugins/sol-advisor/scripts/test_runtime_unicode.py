"""Regression for Unicode separators inside JSONL content; no native agents."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parent
THREAD = "aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa"
TURN = {"model": "gpt-6-luna", "effort": "high", "cwd": "/fixture"}


class RuntimeUnicodeTests(unittest.TestCase):
    def setUp(self):
        self.shell = shutil.which("sh")
        if not self.shell:
            self.skipTest("POSIX shell unavailable")
        self.tmp = tempfile.TemporaryDirectory(prefix="sol-unicode-")
        self.addCleanup(self.tmp.cleanup)
        self.sessions = Path(self.tmp.name)
        self.rollout = self.sessions / f"rollout-unicode-{THREAD}.jsonl"

    def inspect(self, content, ending="\n", later=None, invalid=False):
        rows = [
            {"type": "session_meta", "payload": {"id": THREAD, "agent_role": "fixture_scout"}},
            {"type": "turn_context", "payload": TURN},
            {"type": "response_item", "payload": {"text": "PRIVATE_CONTENT:" + content}},
        ]
        if later is not None:
            rows.append({"type": "turn_context", "payload": later})
        data = ending.join(json.dumps(row, ensure_ascii=False) for row in rows) + ending
        if invalid:
            data += '{"text":"PRIVATE_CONTENT:first\nsecond"}\n'
        self.rollout.write_bytes(data.encode("utf-8"))
        result = subprocess.run(
            [self.shell, str(SCRIPT / "inspect-agent-runtime.sh"),
             "--sessions-dir", str(self.sessions), THREAD], capture_output=True)
        self.assertNotIn(b"PRIVATE_CONTENT", result.stdout + result.stderr)
        return result

    def test_lf_and_crlf_preserve_unicode_separators_inside_json(self):
        for ending in ("\n", "\r\n"):
            for content in ("plain text", "NEL:\u0085 LS:\u2028 PS:\u2029"):
                with self.subTest(ending=repr(ending), content=ascii(content)):
                    result = self.inspect(content, ending)
                    self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                    self.assertEqual(json.loads(result.stdout), {
                        "thread_id": THREAD, "agent_role": "fixture_scout",
                        "parent_thread_id": None, "agent_path": None, "model_provider": None,
                        **TURN, "sandbox_policy_type": None, "permission_profile_type": None,
                    })

    def test_unescaped_lf_inside_json_string_remains_invalid(self):
        self.assertNotEqual(self.inspect("plain text", invalid=True).returncode, 0)

    def test_unicode_content_does_not_bypass_configuration_drift_check(self):
        self.assertNotEqual(self.inspect("\u0085\u2028\u2029", later={**TURN, "effort": "xhigh"}).returncode, 0)


if __name__ == "__main__":
    unittest.main()
