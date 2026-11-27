import tempfile
import unittest
from pathlib import Path

from closure import base_needs, close, features, pair_collectors, read


class BaseNeeds(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.components = Path(self.temp.name) / "components"

    def tearDown(self):
        self.temp.cleanup()

    def write(self, path, image, version=None, requires=""):
        directory = self.components / path
        directory.mkdir(parents=True, exist_ok=True)
        option = ""
        if version is not None:
            option = f'option "version" type="string" {{\n    default "{version}"\n}}\n'
        (directory / "component.kdl").write_text(
            f'schema-version 1\n\n{requires}base "{image}" {{\n'
            f'    family "fedora"\n}}\n{option}'
        )

    def test_requirements_come_from_the_base_built_from_the_reference(self):
        self.write("base-image/plain", "example.invalid/plain:{version}", "1")
        self.write(
            "base-image/seeded",
            "example.invalid/seeded:{version}",
            "1",
            'requires "bootc-base"\nrequires "network"\n',
        )

        self.assertEqual(
            base_needs(self.components, "example.invalid/seeded:1"),
            ([], ["bootc-base", "network"], []),
        )

    def test_a_block_lists_requirements_beside_its_line_form(self):
        self.write(
            "base-image/seeded",
            "example.invalid/seeded:1",
            requires='requires "bootc-base"\nrequires {\n    "network"\n}\n'
            'component "/" {\n    os-release { edition "server" }\n}\n',
        )

        self.assertEqual(
            base_needs(self.components, "example.invalid/seeded:1"),
            ([], ["bootc-base", "network"], ["os-release"]),
        )

    def test_the_version_default_is_written_into_the_reference(self):
        self.write("base-image/seeded", "example.invalid/seeded:{version}", "2")

        with self.assertRaisesRegex(SystemExit, "no base component"):
            base_needs(self.components, "example.invalid/seeded:1")

    def test_a_component_that_is_not_a_base_is_passed_over(self):
        directory = self.components / "tools"
        directory.mkdir(parents=True)
        (directory / "component.kdl").write_text('description "built on example.invalid/tools:1"\n')

        with self.assertRaisesRegex(SystemExit, "no base component"):
            base_needs(self.components, "example.invalid/tools:1")

    def test_a_digest_matches_its_tag(self):
        self.write("base-image/seeded", "example.invalid/seeded:1")

        self.assertEqual(
            base_needs(self.components, "example.invalid/seeded:1@sha256:abc"), ([], [], [])
        )

    def test_two_bases_on_one_reference_stop_the_leg(self):
        self.write("base-image/one", "example.invalid/duplicate:1")
        self.write("base-image/two", "example.invalid/duplicate:1")

        with self.assertRaisesRegex(SystemExit, "more than one base component"):
            base_needs(self.components, "example.invalid/duplicate:1")


class Close(unittest.TestCase):
    COMPONENTS = {
        "build-environment/dnf": (set(), {"build-environment"}, set(), set()),
        "os-release": (set(), {"os-release"}, set(), set()),
        "bootc-base/apt": (set(), {"bootc-base"}, {"container-runtime"}, set()),
        "container-environment/runtime/podman": (set(), {"container-runtime"}, set(), set()),
        "editor": (set(), {"editor"}, {"build-environment"}, set()),
        "suite": (set(), {"suite"}, set(), {"os-release"}),
    }

    def test_a_component_the_base_lists_is_never_printed(self):
        needs = ([], [], ["build-environment/dnf"])
        printed = close(self.COMPONENTS, "fedora", needs, ["editor", "build-environment/dnf"])

        self.assertEqual(printed, ["editor"])

    def test_what_a_component_the_base_lists_requires_is_printed(self):
        needs = ([], [], ["bootc-base/apt"])
        printed = close(self.COMPONENTS, "debian", needs, [])

        self.assertEqual(printed, ["container-environment/runtime/podman"])

    def test_a_component_a_printed_component_lists_is_never_printed(self):
        printed = close(self.COMPONENTS, "fedora", ([], [], []), ["suite"])

        self.assertEqual(printed, ["suite"])


class TreeCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.components = Path(self.temp.name) / "components"

    def tearDown(self):
        self.temp.cleanup()

    def write(self, path, text):
        directory = self.components / path
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "component.kdl").write_text(text)
        return directory / "component.kdl"


class Read(TreeCase):
    def test_a_component_path_takes_the_option_default(self):
        manifest = self.write(
            "media-codecs",
            'schema-version 1\n\noption "repo" type="string" {\n    default "fedora-free"\n}\n'
            'component "/media-codecs/{repo}"\n',
        )

        self.assertEqual(read(manifest, "media-codecs", "fedora")[3], {"media-codecs/fedora-free"})

    def test_a_component_path_before_the_option_still_resolves(self):
        manifest = self.write(
            "media-codecs",
            'schema-version 1\n\ncomponent "/media-codecs/{repo}"\n\n'
            'option "repo" type="string" {\n    default "fedora-free"\n}\n',
        )

        self.assertEqual(read(manifest, "media-codecs", "fedora")[3], {"media-codecs/fedora-free"})

    def test_a_component_path_without_a_default_stays_unresolved(self):
        manifest = self.write(
            "media-codecs",
            'schema-version 1\n\noption "repo" type="string" {\n    description "x"\n}\n'
            'component "/media-codecs/{repo}"\n',
        )

        self.assertEqual(read(manifest, "media-codecs", "fedora")[3], {"media-codecs/{repo}"})


class ReadTree(TreeCase):
    def test_a_component_named_remove_is_a_component_path(self):
        manifest = self.write("image", 'schema-version 1\ncomponent "/" {\n    remove\n}\n')

        self.assertEqual(read(manifest, "image", "fedora")[3], {"remove"})

    def test_a_nested_component_named_remove_is_a_component_path(self):
        manifest = self.write(
            "image", 'schema-version 1\ncomponent "/" {\n    tools {\n        remove\n    }\n}\n'
        )

        self.assertEqual(read(manifest, "image", "fedora")[3], {"tools", "tools/remove"})

    def test_a_list_value_block_is_not_a_component_path(self):
        manifest = self.write(
            "image",
            'schema-version 1\ncomponent "/" {\n    flatpak {\n        flatpaks {\n'
            '            "a"\n            remove "b"\n        }\n    }\n}\n',
        )

        self.assertEqual(read(manifest, "image", "fedora")[3], {"flatpak"})


class PairCollectors(unittest.TestCase):
    def test_a_contributor_reaches_each_leg_that_collects_its_file(self):
        groups = [["one"], ["two"]]
        texts = {
            "one": 'collects "a.list"\n',
            "two": 'collects "b.list"\n',
            "both": 'contributes "a.list"\ncontributes "b.list"\n',
        }

        pair_collectors(groups, texts)

        self.assertEqual(groups, [["one", "both"], ["two", "both"]])


class Features(TreeCase):
    def test_a_base_and_an_option_directory_are_not_features(self):
        self.write("base-image/fedora", 'schema-version 1\n\nbase "example.invalid/fedora:1" {\n    family "fedora"\n}\n')
        self.write("media-codecs/fedora-free", 'schema-version 1\n\ntargets "fedora"\n')
        self.write("media-codecs/rpm-fusion", 'schema-version 1\n\ntargets "fedora"\n')
        self.write("media-codecs/negativo17", 'schema-version 1\n\ntargets "fedora"\n')
        self.write(
            "media-codecs",
            'schema-version 1\n\noption "repo" type="string" {\n    default "fedora-free"\n}\n'
            'component "/media-codecs/{repo}"\n',
        )
        self.write("build-environment/dnf", 'schema-version 1\n')

        self.assertEqual(features(self.components), ["build-environment/dnf", "media-codecs"])


if __name__ == "__main__":
    unittest.main()
