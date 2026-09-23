"""Static role and GPT-6 route checks; no native-agent execution."""
from pathlib import Path
import json
import shutil
import subprocess
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
ROLES = ("scout", "worker", "reviewer")
MODEL_EFFORTS = {
    "gpt-6-luna": ("high", "xhigh", "max"),
    "gpt-6-sol": ("low", "medium", "high", "xhigh", "max"),
    "gpt-6-astra": ("low", "medium", "high", "xhigh", "max"),
}


class ConfigurationTests(unittest.TestCase):
    def test_roles_leave_model_effort_and_capabilities_to_dispatch_and_host(self):
        self.assertEqual({p.name for p in (ROOT / "agents").glob("*.toml")},
                         {f"sol-advisor-{role}.toml" for role in ROLES})
        for role in ROLES:
            with self.subTest(role=role):
                path = ROOT / "agents" / f"sol-advisor-{role}.toml"
                self.assertNotIn(b"\r", path.read_bytes())
                data = tomllib.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(data["name"], f"sol_advisor_{role}")
                self.assertEqual(data["model_provider"], "openai")
                self.assertTrue(data["description"])
                self.assertTrue(data["developer_instructions"])
                # Profiles must not disable messaging, override inherited permissions,
                # or pin effort over a per-task choice. This does not prove runtime isolation.
                self.assertEqual(set(data), {"name", "description", "model_provider", "developer_instructions"})

    def test_all_roles_accept_each_supported_model_effort(self):
        shell = shutil.which("sh")
        if not shell:
            self.skipTest("POSIX shell unavailable")
        command = [shell, str(ROOT / "scripts/validate-agent-route.sh")]
        for role in ROLES:
            for model, efforts in MODEL_EFFORTS.items():
                for effort in efforts:
                    with self.subTest(role=role, model=model, effort=effort):
                        suffix = model.replace("-", "_")
                        valid = [f"sol_advisor_{role}", "openai", model, effort, "check__" + suffix]
                        result = subprocess.run(command + valid, capture_output=True)
                        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))

    def test_route_rejects_legacy_roles_invalid_fields_and_luna_below_high(self):
        shell = shutil.which("sh")
        if not shell:
            self.skipTest("POSIX shell unavailable")
        command = [shell, str(ROOT / "scripts/validate-agent-route.sh")]
        valid = ["sol_advisor_scout", "openai", "gpt-6-luna", "high", "check__gpt_6_luna"]
        invalid_fields = (
            (0, "sol_advisor_mechanical_editor"),
            (0, "sol_advisor_scout__gpt_5_6_luna"),
            (0, "sol_advisor_worker__gpt_5_6_sol"),
            (0, "sol_advisor_reviewer__gpt_5_6_sol"),
            (0, "sol_advisor_reviewer__gpt_6_astra"),
            (1, "other"), (2, "gpt-5.6-luna"), (2, "wrong-model"),
            (3, "automatic"), (3, "low"), (3, "medium"), (3, "none"), (3, "ultra"),
            (4, "check__wrong_model"), (4, ""), (4, "Invalid__gpt_6_luna"),
        )
        for index, value in invalid_fields:
            with self.subTest(index=index, value=value):
                invalid = valid.copy()
                invalid[index] = value
                self.assertNotEqual(subprocess.run(command + invalid, capture_output=True).returncode, 0)
        for model in ("gpt-6-sol", "gpt-6-astra"):
            for effort in ("none", "ultra"):
                invalid = [valid[0], "openai", model, effort, "check__" + model.replace("-", "_")]
                self.assertNotEqual(subprocess.run(command + invalid, capture_output=True).returncode, 0)

    def test_plugin_metadata_and_local_links(self):
        manifest = json.loads((ROOT / ".codex-plugin/plugin.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["name"], "sol-advisor")
        self.assertEqual(manifest["version"], "3.0.0")
        self.assertTrue((ROOT / manifest["skills"]).is_dir())
        self.assertTrue((ROOT / manifest["mcpServers"]).is_file())
        prompts = manifest["interface"]["defaultPrompt"]
        self.assertLessEqual(len(prompts), 3)
        self.assertTrue(all(isinstance(p, str) and 0 < len(p) <= 128 for p in prompts))
        self.assertFalse((ROOT / "skills/orchestration/references/routing.md").exists())


if __name__ == "__main__":
    unittest.main()
