"""Run the fedora-remote layer script against a temporary root.

    python3 -m unittest discover -s components/flatpak/fedora-remote
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
LAYER = HERE / "component.sh"
LIB = HERE.parent / "lib"
DEFAULTS = "/usr/share/flatpak-defaults"


def rooted(root):
    text = LAYER.read_text()
    # If the script stops naming the defaults path, then the no-list assertions would pass against a root the script never writes to.
    if DEFAULTS not in text:
        raise AssertionError(f"{LAYER} no longer names {DEFAULTS}")
    text = text.replace(DEFAULTS, f"{root}{DEFAULTS}")
    return text.replace("/ctx/lib", str(LIB))


class FedoraRemoteList(unittest.TestCase):
    def run_layer(self, root, ids):
        array = " ".join(f"'{flatpak_id}'" for flatpak_id in ids)
        ran = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", f"OPT_FLATPAKS=({array})\n{rooted(root)}"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(ran.returncode, 0, ran.stderr)

    def test_the_option_writes_the_fedora_remote_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.run_layer(root, ["org.gnome.Calculator"])
            written = (root / DEFAULTS.lstrip("/") / "remotes" / "fedora.list").read_text()
        self.assertEqual(written, "org.gnome.Calculator\n")

    def test_an_empty_option_writes_no_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.run_layer(root, [])
            self.assertFalse((root / DEFAULTS.lstrip("/")).exists())


if __name__ == "__main__":
    unittest.main()
