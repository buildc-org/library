"""Run the flatpak layer script and the first-boot install against a temporary root.

    python3 -m unittest discover -s components/flatpak
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
LAYER = HERE / "component.sh"
INSTALL = HERE / "files/usr/libexec/install-flatpaks"
LIB = HERE / "lib"
DEFAULTS = "/usr/share/flatpak-defaults"

FAKE_FLATPAK = (
    "#!/bin/sh\n"
    'echo "$@" >> "$FLATPAK_LOG"\n'
    'case "$*" in\n'
    "    *org.fail.App*) exit 1 ;;\n"
    "esac\n"
)


def rooted(script, root):
    text = script.read_text()
    # If the script stops naming the defaults path, then the no-list assertions would pass against a root the script never writes to.
    if DEFAULTS not in text:
        raise AssertionError(f"{script} no longer names {DEFAULTS}")
    text = text.replace(DEFAULTS, f"{root}{DEFAULTS}")
    return text.replace("/ctx/lib", str(LIB))


class FlatpakLists(unittest.TestCase):
    def run_layer(self, root, ids):
        array = " ".join(f"'{flatpak_id}'" for flatpak_id in ids)
        ran = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", f"OPT_FLATPAKS=({array})\n{rooted(LAYER, root)}"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(ran.returncode, 0, ran.stderr)

    def run_install(self, root, expect_ok=True):
        bin_dir = root / "bin"
        bin_dir.mkdir()
        (bin_dir / "flatpak").write_text(FAKE_FLATPAK)
        (bin_dir / "flatpak").chmod(0o755)
        log = root / "flatpak.log"
        ran = subprocess.run(
            ["bash", "-c", rooted(INSTALL, root)],
            env={"PATH": f"{bin_dir}:{os.environ['PATH']}", "FLATPAK_LOG": str(log)},
            capture_output=True,
            text=True,
        )
        if expect_ok:
            self.assertEqual(ran.returncode, 0, ran.stderr)
        else:
            self.assertNotEqual(ran.returncode, 0, ran.stderr)
        return log.read_text().splitlines()

    def test_the_image_list_and_the_collected_list_both_install_from_flathub(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.run_layer(root, ["org.mozilla.Thunderbird", "org.gnome.Calculator"])
            # The comment line and the trailing blank line check that the install step skips both kinds of line.
            (root / DEFAULTS.lstrip("/") / "apps.list").write_text(
                "# from flatpak/app/bitwarden\ncom.bitwarden.desktop\n\n"
            )
            calls = self.run_install(root)
        self.assertEqual(
            calls,
            [
                "remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo",
                "install --system -y --noninteractive flathub org.mozilla.Thunderbird",
                "install --system -y --noninteractive flathub org.gnome.Calculator",
                "install --system -y --noninteractive flathub com.bitwarden.desktop",
            ],
        )

    def test_an_empty_option_writes_no_list_and_installs_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.run_layer(root, [])
            self.assertFalse((root / DEFAULTS.lstrip("/")).exists())
            calls = self.run_install(root)
        self.assertEqual(
            calls,
            ["remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"],
        )

    def test_a_shipped_remote_installs_its_own_list_from_its_own_remote(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            remotes = root / DEFAULTS.lstrip("/") / "remotes"
            remotes.mkdir(parents=True)
            (remotes / "fedora.flatpakrepo").write_text(
                "[Flatpak Repo]\nTitle=Fedora\nUrl=oci+https://registry.fedoraproject.org\n"
            )
            (remotes / "fedora.list").write_text("org.gnome.Calculator\n")
            calls = self.run_install(root)
        self.assertEqual(
            calls,
            [
                "remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo",
                f"remote-add --if-not-exists fedora --from {remotes / 'fedora.flatpakrepo'}",
                "install --system -y --noninteractive fedora org.gnome.Calculator",
            ],
        )

    def test_a_remote_list_with_no_shipped_repo_file_still_installs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            remotes = root / DEFAULTS.lstrip("/") / "remotes"
            remotes.mkdir(parents=True)
            (remotes / "rhel.list").write_text("org.mozilla.Thunderbird\n")
            calls = self.run_install(root)
        self.assertEqual(
            calls,
            [
                "remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo",
                "install --system -y --noninteractive rhel org.mozilla.Thunderbird",
            ],
        )

    def test_a_list_with_no_final_newline_still_installs_its_last_id(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            defaults = root / DEFAULTS.lstrip("/")
            defaults.mkdir(parents=True)
            (defaults / "image.list").write_text("org.gnome.Calculator")
            calls = self.run_install(root)
        self.assertEqual(
            calls,
            [
                "remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo",
                "install --system -y --noninteractive flathub org.gnome.Calculator",
            ],
        )

    def test_a_failed_install_does_not_stop_the_rest_and_the_script_still_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.run_layer(root, ["org.fail.App", "org.gnome.Calculator"])
            calls = self.run_install(root, expect_ok=False)
        self.assertEqual(
            calls,
            [
                "remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo",
                "install --system -y --noninteractive flathub org.fail.App",
                "install --system -y --noninteractive flathub org.gnome.Calculator",
            ],
        )


if __name__ == "__main__":
    unittest.main()
