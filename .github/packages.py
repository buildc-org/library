#!/usr/bin/env python3
"""Print `<component> <package>...` for every component declaring packages for one family.

The `packages` job dry-runs each line in a container of that family. One line
per component lets the job name the component whose package does not resolve.
Run from the library root.

    packages.py <family>
    packages.py <family> --repos
    packages.py <family> --helpers

`--repos` prints a shell script that sources every `repo.sh` this family would
run instead. The job runs it first, because a package from a third-party
archive resolves only after its archive is added. Each repository script runs
with the asset environment its component declares, which is what `buildc`
provides inside a layer. A component that declares no packages is listed too. It
can enable an archive section that other components install from.

`--helpers` prints the `helpers` files this family's components declare. The
job copies them to `/ctx/lib` before it runs the repository script, because a
repository script may source one.

Only components that target the family are read, as in the `collection` leg of
that family.
"""

import re
import shlex
import sys
from pathlib import Path

from closure import nodes
from pins import pins

COMPONENTS = Path("components")
QUOTED = re.compile(r'"([^"]*)"')


def lists(text, family):
    """Every package name one manifest installs on one family, in file order.

    Packages outside a gate apply to every family the component targets.
    Packages inside a gate apply only to the families it names. A `packages`
    node writes its names on its line or as the children of its block.
    """
    if not targets(text, family):
        return []
    names = []
    for parents, name, args in nodes(text):
        gates = [given for kind, given in parents if kind == "on"]
        if any(family not in gate for gate in gates):
            continue
        if name == "packages" and args:
            names += args
        elif parents and parents[-1][0] == "packages":
            names.append(name)
    return names


def targets(text, family):
    """Whether a manifest builds on `family`. No `targets` is every family."""
    lines = re.findall(r'^targets\s(.*)$', text, re.M)
    return not lines or any(family in QUOTED.findall(line) for line in lines)


FAMILY_DIRS = {
    "debian": ["debian/", "deb/", ""],
    "ubuntu": ["ubuntu/", "deb/", ""],
    "fedora": ["fedora/", ""],
}


def repo(component, family):
    """The `repo.sh` this component ships for this family, if it ships one."""
    for at in FAMILY_DIRS.get(family, [""]):
        found = component / at / "repo.sh"
        if found.is_file():
            return found
    return None


def helper_files(component, text):
    """Every helper file one component declares, as a path below the library root."""
    return [
        (component / arg).as_posix()
        for parents, name, args in nodes(text)
        if name == "helpers" and not parents
        for arg in args
    ]


def repo_script(text, repo):
    """The shell that sources one repository script with the component's assets exported."""
    lines = [f"    export {name}={shlex.quote(value)}" for name, value in pins(text)]
    lines.append(f"    source {shlex.quote(repo.as_posix())}")
    return "(\n" + "\n".join(lines) + "\n)"


def main(argv):
    if len(argv) not in (2, 3) or (len(argv) == 3 and argv[2] not in ("--repos", "--helpers")):
        sys.exit(__doc__)
    family, mode = argv[1], argv[2] if len(argv) == 3 else None
    if mode == "--repos":
        print("set -euo pipefail")
    for manifest in sorted(COMPONENTS.rglob("manifest.kdl")):
        if any(part.startswith(".") for part in manifest.parts[:-1]):
            continue
        text = manifest.read_text()
        if not targets(text, family):
            continue
        if mode == "--repos":
            found = repo(manifest.parent, family)
            if found:
                print(repo_script(text, found))
            continue
        if mode == "--helpers":
            for path in helper_files(manifest.parent, text):
                print(path)
            continue
        names = lists(text, family)
        if names:
            print(manifest.parent.relative_to(COMPONENTS).as_posix(), *names)


if __name__ == "__main__":
    main(sys.argv)
