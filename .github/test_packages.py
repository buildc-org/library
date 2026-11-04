import unittest
from pathlib import Path

from packages import helper_files, lists, repo_script

MANIFEST = """schema-version 1
packages "htop"
packages enablerepo="secureblue" {
    "trivalent"
    "trivalent-qt6-ui"
}
on "fedora" {
    packages {
        "dnf-plugins-core"
    }
}
on "debian" "ubuntu" { packages "apt-utils"; }
"""

ASSET = """schema-version 1
asset "cuda-keyring" {
    pin {
        version "1.1-1"
        url "https://example/{version}/key.deb"
        sha256 "abc"
    }
}
"""


class Lists(unittest.TestCase):
    def test_a_block_lists_its_names_and_drops_the_batch_property(self):
        self.assertEqual(
            lists(MANIFEST, "fedora"),
            ["htop", "trivalent", "trivalent-qt6-ui", "dnf-plugins-core"],
        )

    def test_a_gate_keeps_only_the_families_it_names(self):
        self.assertEqual(
            lists(MANIFEST, "debian"),
            ["htop", "trivalent", "trivalent-qt6-ui", "apt-utils"],
        )


class Helpers(unittest.TestCase):
    def test_a_helper_path_is_resolved_from_the_component_dir(self):
        self.assertEqual(
            helper_files(Path("components/x"), 'helpers "lib/a.sh" "lib/b.sh"\n'),
            ["components/x/lib/a.sh", "components/x/lib/b.sh"],
        )

    def test_a_helper_inside_a_gate_is_not_counted(self):
        self.assertEqual(helper_files(Path("components/x"), 'on "fedora" { helpers "lib/a.sh" }\n'), [])


class RepoScript(unittest.TestCase):
    def test_the_script_exports_the_component_assets_before_it_sources_the_repo(self):
        self.assertEqual(
            repo_script(ASSET, Path("components/x/repo.sh")),
            "(\n"
            "    export ASSET_CUDA_KEYRING_VERSION=1.1-1\n"
            "    export ASSET_CUDA_KEYRING_URL=https://example/1.1-1/key.deb\n"
            "    export ASSET_CUDA_KEYRING_SHA256=abc\n"
            "    source components/x/repo.sh\n"
            ")",
        )


if __name__ == "__main__":
    unittest.main()
