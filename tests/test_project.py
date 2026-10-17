from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ProjectSmokeTests(unittest.TestCase):
    def test_required_pages_and_backend_files_exist(self):
        required = [
            "web/index.html",
            "web/dashboard.html",
            "web/plan.html",
            "web/workout.html",
            "web/diet.html",
            "supabase/schema.sql",
            "supabase/storage-setup.sql",
            "supabase/functions/recognize-food/index.ts",
        ]
        for relative in required:
            self.assertTrue((ROOT / relative).is_file(), relative)

    def test_html_pages_use_shared_placeholder_config(self):
        for page in (ROOT / "web").glob("*.html"):
            text = page.read_text(encoding="utf-8")
            self.assertIn("./js/supabase-config.js", text, page.name)
            self.assertRegex(text, r'<meta\s+name="viewport"', page.name)
        config = (ROOT / "web/js/supabase-config.js").read_text(encoding="utf-8")
        self.assertIn("YOUR-PROJECT-REF", config)
        self.assertIn("YOUR-ANON-PUBLIC-KEY", config)

    def test_schema_matches_recognition_payload(self):
        schema = (ROOT / "supabase/schema.sql").read_text(encoding="utf-8")
        self.assertIn("ai_confidence", schema)
        self.assertIn("llm_raw_response", schema)
        self.assertIn("enable row level security", schema.lower())

    def test_no_private_key_or_service_role_value_is_committed(self):
        secret_pattern = re.compile(
            r"(?:sk-[A-Za-z0-9_-]{20,}|BEGIN (?:RSA|OPENSSH|EC) PRIVATE KEY)"
        )
        for path in ROOT.rglob("*"):
            if not path.is_file() or ".git" in path.parts:
                continue
            try:
                content = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            self.assertIsNone(secret_pattern.search(content), str(path))


class ConfigInjectionTests(unittest.TestCase):
    def _workspace(self, destination: Path) -> None:
        (destination / "scripts").mkdir()
        (destination / "web/js").mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/inject-config.sh", destination / "scripts")
        shutil.copy2(
            ROOT / "web/js/supabase-config.js",
            destination / "web/js/supabase-config.js",
        )

    def test_missing_environment_fails_without_modifying_config(self):
        with tempfile.TemporaryDirectory() as temporary:
            workspace = Path(temporary)
            self._workspace(workspace)
            config = workspace / "web/js/supabase-config.js"
            before = config.read_bytes()
            environment = os.environ.copy()
            environment.pop("SUPABASE_URL", None)
            environment.pop("SUPABASE_ANON_KEY", None)

            result = subprocess.run(
                ["bash", "scripts/inject-config.sh"],
                cwd=workspace,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(config.read_bytes(), before)

    def test_valid_environment_is_injected_without_echoing_key(self):
        with tempfile.TemporaryDirectory() as temporary:
            workspace = Path(temporary)
            self._workspace(workspace)
            environment = os.environ.copy()
            environment["SUPABASE_URL"] = "https://demo.supabase.co"
            environment["SUPABASE_ANON_KEY"] = "public-anon-test-value"

            result = subprocess.run(
                ["bash", "scripts/inject-config.sh"],
                cwd=workspace,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )
            content = (workspace / "web/js/supabase-config.js").read_text(
                encoding="utf-8"
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("https://demo.supabase.co", content)
            self.assertIn("public-anon-test-value", content)
            self.assertNotIn("public-anon-test-value", result.stdout)
            probe = subprocess.run(
                [
                    "node",
                    "-e",
                    (
                        "const fs=require('node:fs'),vm=require('node:vm');"
                        "const c={window:{}};vm.createContext(c);"
                        "vm.runInContext(fs.readFileSync(process.argv[1],'utf8'),c);"
                        "if(!vm.runInContext('isSupabaseConfigured()',c))process.exit(1);"
                    ),
                    str(workspace / "web/js/supabase-config.js"),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(probe.returncode, 0, probe.stderr)


if __name__ == "__main__":
    unittest.main()
