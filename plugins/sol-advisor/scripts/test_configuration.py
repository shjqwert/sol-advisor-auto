"""Static model-profile and route checks; no native-agent execution."""
from pathlib import Path
import json
import shutil
import subprocess
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROFILES = {
    "sol-advisor-scout__gpt_5_6_luna.toml": ("scout", "gpt-5.6-luna", "high"),
    "sol-advisor-worker__gpt_5_6_sol.toml": ("worker", "gpt-5.6-sol", "medium"),
    "sol-advisor-reviewer__gpt_5_6_sol.toml": ("reviewer", "gpt-5.6-sol", "high"),
    "sol-advisor-reviewer__gpt_6_astra.toml": ("reviewer", "gpt-6-astra", "xhigh"),
}


class ConfigurationTests(unittest.TestCase):
    def test_profiles_match_model_names_and_keep_inherited_tools(self):
        self.assertEqual({p.name for p in (ROOT / "agents").glob("*.toml")}, set(PROFILES))
        for filename, (role, model, _) in PROFILES.items():
            with self.subTest(profile=filename):
                path = ROOT / "agents" / filename
                self.assertNotIn(b"\r", path.read_bytes())
                data = tomllib.loads(path.read_text(encoding="utf-8"))
                suffix = model.replace(".", "_").replace("-", "_")
                self.assertEqual(data["name"], f"sol_advisor_{role}__{suffix}")
                self.assertEqual(data["model"], model)
                self.assertEqual(data["model_provider"], "openai")
                self.assertTrue(data["description"])
                self.assertTrue(data["developer_instructions"])
                # Profiles must not disable messaging, override inherited permissions,
                # or pin effort over a per-task choice. This does not prove runtime isolation.
                self.assertEqual(set(data), {"name", "description", "model", "model_provider", "developer_instructions"})

    def test_route_rejects_model_identity_and_instance_name_mismatches(self):
        shell = shutil.which("sh")
        if not shell:
            self.skipTest("POSIX shell unavailable")
        command = [shell, str(ROOT / "scripts/validate-agent-route.sh")]
        for filename, (_, model, effort) in PROFILES.items():
            data = tomllib.loads((ROOT / "agents" / filename).read_text(encoding="utf-8"))
            suffix = model.replace(".", "_").replace("-", "_")
            valid = [data["name"], "openai", model, effort, "check__" + suffix]
            with self.subTest(profile=filename):
                result = subprocess.run(command + valid, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                for index, value in ((0, "sol_advisor_mechanical_editor"), (1, "other"),
                                     (2, "wrong-model"), (3, "automatic"), (4, "check__wrong_model")):
                    invalid = valid.copy()
                    invalid[index] = value
                    self.assertNotEqual(subprocess.run(command + invalid, capture_output=True).returncode, 0)

    def test_plugin_metadata_and_local_links(self):
        manifest = json.loads((ROOT / ".codex-plugin/plugin.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["name"], "sol-advisor")
        self.assertEqual(manifest["version"], "2.0.0")
        self.assertTrue((ROOT / manifest["skills"]).is_dir())
        self.assertTrue((ROOT / manifest["mcpServers"]).is_file())
        prompts = manifest["interface"]["defaultPrompt"]
        self.assertLessEqual(len(prompts), 3)
        self.assertTrue(all(isinstance(p, str) and 0 < len(p) <= 128 for p in prompts))
        self.assertFalse((ROOT / "skills/orchestration/references/routing.md").exists())


if __name__ == "__main__":
    unittest.main()
