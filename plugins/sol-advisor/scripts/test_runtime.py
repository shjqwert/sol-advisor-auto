"""Synthetic rollout diagnostics; these checks do not execute native agents."""
from copy import deepcopy
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parent
THREAD = "11111111-1111-7111-8111-111111111111"
PARENT = "00000000-0000-7000-8000-000000000000"
IDENTITY = {"agent_role": "sol_advisor_scout", "parent_thread_id": PARENT,
            "agent_path": "/root/trace__gpt_6_luna"}
TURN = {"model": "gpt-6-luna", "effort": "high", "cwd": "/fixture/cwd"}


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.shell = shutil.which("sh")
        if not self.shell:
            self.skipTest("POSIX shell unavailable")
        self.tmp = tempfile.TemporaryDirectory(prefix="sol-runtime-")
        self.addCleanup(self.tmp.cleanup)
        self.sessions = Path(self.tmp.name)
        self.rollout = self.sessions / f"rollout-2026-09-23T00-00-00-{THREAD}.jsonl"

    def inspect(self, meta, turns=None, extra=None):
        items = [{"type": "session_meta", "payload": meta},
                 {"type": "response_item", "payload": {"prompt": "DO_NOT_LEAK_RUNTIME"}}]
        items.extend({"type": "turn_context", "payload": turn}
                     for turn in (turns if turns is not None else [TURN, TURN]))
        items.extend(extra or [])
        self.rollout.write_text("\n".join(json.dumps(item) for item in items) + "\n", encoding="utf-8")
        result = subprocess.run(
            [self.shell, str(SCRIPT / "inspect-agent-runtime.sh"),
             "--sessions-dir", str(self.sessions), THREAD], capture_output=True)
        self.assertNotIn(b"DO_NOT_LEAK_RUNTIME", result.stdout + result.stderr)
        return result

    def metadata(self, nested=False):
        meta = {"id": THREAD, "model_provider": "openai"}
        if nested:
            meta["source"] = {"subagent": {"thread_spawn": deepcopy(IDENTITY)}}
        else:
            meta.update(IDENTITY)
        return meta

    def test_legacy_v2_and_matching_dual_identity_return_only_allowlisted_fields(self):
        legacy, nested = self.metadata(), self.metadata(nested=True)
        both = deepcopy(nested)
        both.update(IDENTITY)
        for meta in (legacy, nested, both):
            with self.subTest(meta=meta):
                result = self.inspect(meta)
                self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                data = json.loads(result.stdout)
                self.assertEqual(data, {
                    "thread_id": THREAD, **IDENTITY, "model_provider": "openai",
                    **TURN, "sandbox_policy_type": None, "permission_profile_type": None,
                })

    def test_conflicting_or_invalid_identity_is_rejected(self):
        for key in IDENTITY:
            for value in ("conflicting", "", 42):
                with self.subTest(key=key, value=value):
                    meta = self.metadata(nested=True)
                    meta[key] = value
                    self.assertNotEqual(self.inspect(meta).returncode, 0)

    def test_missing_role_never_infers_role_from_name_or_model(self):
        for nested in (False, True):
            meta = self.metadata(nested=nested)
            location = meta["source"]["subagent"]["thread_spawn"] if nested else meta
            del location["agent_role"]
            self.assertNotEqual(self.inspect(meta).returncode, 0)
        meta = self.metadata(nested=True)
        meta["source"]["subagent"]["thread_spawn"] = "malformed"
        self.assertNotEqual(self.inspect(meta).returncode, 0)

    def test_missing_and_changing_turn_configuration_is_rejected(self):
        for key, changed in (("model", "gpt-6-sol"), ("effort", "xhigh"), ("cwd", "/other")):
            for value in (changed, None, ""):
                with self.subTest(key=key, value=value):
                    later = {**TURN, key: value}
                    self.assertNotEqual(self.inspect(self.metadata(True), [TURN, later]).returncode, 0)
        self.assertNotEqual(self.inspect(self.metadata(), []).returncode, 0)

    def test_missing_optional_identity_is_reported_as_unknown(self):
        meta = {"id": THREAD, "agent_role": "sol_advisor_worker"}
        result = self.inspect(meta)
        self.assertEqual(result.returncode, 0)
        data = json.loads(result.stdout)
        for key in ("parent_thread_id", "agent_path", "model_provider"):
            self.assertIsNone(data[key])

    def test_ambiguous_rollout_or_session_identity_is_rejected(self):
        meta = self.metadata()
        self.assertNotEqual(self.inspect(meta, extra=[{"type": "session_meta", "payload": meta}]).returncode, 0)
        self.assertNotEqual(self.inspect({**meta, "id": PARENT}).returncode, 0)
        duplicate = self.sessions / f"rollout-2026-09-23T00-00-01-{THREAD}.jsonl"
        duplicate.write_text("DO_NOT_LEAK_RUNTIME", encoding="utf-8")
        self.assertNotEqual(self.inspect(meta).returncode, 0)


if __name__ == "__main__":
    unittest.main()
