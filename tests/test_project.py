from pathlib import Path
import re
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


if __name__ == "__main__":
    unittest.main()
