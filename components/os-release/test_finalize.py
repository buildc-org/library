"""Run the os-release finalize hook against a temporary os-release.

    python3 -m unittest discover -s components/os-release
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).with_name("finalize.sh")

FEDORA = 'NAME="Fedora Linux"\nVERSION_ID=44\nID=fedora\nPRETTY_NAME="Fedora Linux 44"\n'


OPTIONS = (
    "OPT_NAME",
    "OPT_PRETTY_NAME",
    "OPT_DEFAULT_HOSTNAME",
    "OPT_HOME_URL",
    "OPT_DOCUMENTATION_URL",
    "OPT_SUPPORT_URL",
    "OPT_BUG_REPORT_URL",
)


class OsReleaseHook(unittest.TestCase):
    def run_hook(self, regular=False, **env):
        # buildc exports every declared option even when the image leaves it empty.
        options = {name: "" for name in OPTIONS}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "usr/lib/os.release.d").mkdir(parents=True)
            (root / "etc").mkdir()
            (root / "usr/lib/os.release.d/os-release-fedora").write_text(FEDORA)
            if regular:
                (root / "usr/lib/os-release").write_text(FEDORA)
                (root / "etc/os-release").write_text(FEDORA)
            else:
                (root / "usr/lib/os-release").symlink_to("os.release.d/os-release-fedora")
            script = HOOK.read_text().replace(
                "local file=/usr/lib/os-release", f"local file={root}/usr/lib/os-release"
            ).replace("local link=/etc/os-release", f"local link={root}/etc/os-release")
            self.assertNotIn("=/usr/lib/os-release", script)
            self.assertNotIn("=/etc/os-release", script)
            ran = subprocess.run(
                ["bash", "-euo", "pipefail", "-c", script],
                env={"PATH": os.environ["PATH"], **options, **env},
                capture_output=True,
                text=True,
            )
            self.assertEqual(ran.returncode, 0, ran.stderr)
            written = root / "usr/lib/os-release"
            return written.read_text(), (written.is_symlink(), (root / "etc/os-release").resolve() == written)

    def test_keys_are_replaced_in_place_and_absent_ones_appended(self):
        text, (symlink, linked) = self.run_hook(
            OPT_NAME="Workstation", OPT_DEFAULT_HOSTNAME="workstation", IMAGE_VERSION="20261028"
        )
        self.assertEqual(
            text,
            'NAME="Workstation"\nVERSION_ID=44\nID=fedora\nPRETTY_NAME="Workstation 20261028"\n'
            'DEFAULT_HOSTNAME="workstation"\nIMAGE_VERSION="20261028"\n',
        )
        self.assertFalse(symlink)
        self.assertTrue(linked)

    def test_regular_files_are_rewritten_and_etc_becomes_a_link(self):
        text, (symlink, linked) = self.run_hook(regular=True, OPT_NAME="Workstation")
        self.assertIn('NAME="Workstation"\n', text)
        self.assertFalse(symlink)
        self.assertTrue(linked)

    def test_declared_values_are_quoted_and_each_url_reaches_its_own_key(self):
        text, _ = self.run_hook(
            OPT_NAME="Workstation",
            OPT_PRETTY_NAME='The "$HOME" box',
            OPT_HOME_URL="https://example.org",
            OPT_DOCUMENTATION_URL="https://example.org/docs",
            OPT_SUPPORT_URL="https://example.org/support",
            OPT_BUG_REPORT_URL="https://example.org/issues",
        )
        self.assertIn('PRETTY_NAME="The \\"\\$HOME\\" box"\n', text)
        self.assertIn('IMAGE_VERSION="dev"\n', text)
        self.assertIn('HOME_URL="https://example.org"\n', text)
        self.assertIn('DOCUMENTATION_URL="https://example.org/docs"\n', text)
        self.assertIn('SUPPORT_URL="https://example.org/support"\n', text)
        self.assertIn('BUG_REPORT_URL="https://example.org/issues"\n', text)

    def test_an_unset_name_keeps_the_base_name(self):
        text, _ = self.run_hook()
        self.assertEqual(
            text, 'NAME="Fedora Linux"\nVERSION_ID=44\nID=fedora\nPRETTY_NAME="Fedora Linux 44"\n'
            'IMAGE_VERSION="dev"\n',
        )


if __name__ == "__main__":
    unittest.main()
