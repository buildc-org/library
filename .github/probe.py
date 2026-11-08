#!/usr/bin/env python3
"""List what to measure in each base image, and correct a base's `provides`
from what its image ships. Run from the library root.

    probe.py list
    probe.py correct <base directory> <present path>... [--version <package>=<version>]...

`list` prints one `<base directory>|<image>|<family>|<paths>|<packages>` line
for each base component. The paths are the witnesses that the base declares or
that a component targeting its family declares. The public half of a key
witnesses the key's `<kind>-key` capability. The packages are the packages
whose versions measure a provided capability. An empty field is `-`.

`correct` rewrites the `provides` block of the base's manifest. A witnessed
name is declared exactly when the image ships one of its paths. A capability
with a `package` carries the version measured for it. A package whose version
the probe did not measure loses any recorded version. A name without a witness
keeps its line. It prints the change. It prints nothing for a base that already
matches.

A consumer's `base-sig-probe` measures the witnesses of the components its
image holds and edits no component. The correction made here reaches a
consumer as a component update.
"""

import re
import sys

from closure import COMPONENTS, declared, imported, is_base, manifests, read, reference, targets

WITNESS = re.compile(r'^\s*(?:provides\s+)?"([^"]+)"[^\n]*?\bwitness="([^"]+)"', re.M)
KEY = re.compile(r'^\s*key\s+"([^"]+)"\s*\{[^}]*?^\s*public\s+"([^"]+)"', re.M | re.S)
PACKAGE = re.compile(r'^\s*(?:provides\s+)?"([^"]+)"[^\n]*?\bpackage="([^"]+)"', re.M)
FAMILY = re.compile(r'^\s*family\s+"([^"]+)"', re.M)
BLOCK = re.compile(r"^provides \{\n(.*?)^\}\n", re.M | re.S)
LINE = re.compile(r"^provides\s+\"", re.M)


def meets(declared_name, required):
    """Answer whether a declared name meets a requirement. A name meets a
    requirement for itself or for a name above it, as in the tool."""
    return declared_name == required or declared_name.startswith(required + "/")


def pairs(text):
    """Return each witnessed name of one manifest with its path."""
    return WITNESS.findall(text) + [(f"{kind}-key", path) for kind, path in KEY.findall(text)]


def packages(text):
    """Return each provided name with the package whose version measures it."""
    return dict(PACKAGE.findall(text))


def family(text):
    """Return the family that a base manifest declares."""
    found = FAMILY.search(text)
    return found.group(1) if found else ""


def library():
    """Return the base manifests and the other components, by path."""
    bases, components = {}, {}
    for name, manifest, text in manifests(COMPONENTS):
        if is_base(text):
            bases[name] = text
        else:
            components[name] = (read(manifest), pairs(text))
    return bases, components


def witnesses(base, bases, components):
    """Return each witnessed name the probe measures on one base, with its
    paths. A component that the base imports is part of the base component. A
    component that meets a base requirement stands in for the base. The base
    never claims what either provides."""
    text = bases[base]
    declared_family = FAMILY.search(text)
    lists = declared(text, top=True)
    brought = imported({name: parts for name, (parts, _) in components.items()},
                       lists["imports"], [])
    found = {}

    def add(found_pairs):
        for name, path in found_pairs:
            held = found.setdefault(name, [])
            if path not in held:
                held.append(path)

    add(pairs(text))
    for name, (parts, witnessed) in components.items():
        if declared_family and not targets(parts, declared_family.group(1)):
            continue
        stands_in = any(name == req or any(meets(has, req) for has in parts[1])
                        for req in lists["requires"])
        if name in brought or stands_in:
            continue
        add(witnessed)
    return found


def current_versions(text):
    """Return the version each package carries now."""
    found = {}
    for line in text.splitlines():
        package = re.search(r'\bpackage="([^"]+)"', line)
        version = re.search(r'\bversion="([^"]*)"', line)
        if package:
            found[package.group(1)] = version.group(1) if version else ""
    return found


def set_versions(text, measured):
    """Return the manifest text with each `version` set from the measured
    versions. It also returns the packages whose version changed."""
    was = current_versions(text)
    changed = []

    def one(match):
        line = match.group(0)
        package = re.search(r'\bpackage="([^"]+)"', line)
        if not package:
            return line
        name = package.group(1)
        version = measured.get(name, "")
        if was.get(name, "") != version:
            changed.append(name)
        line = re.sub(r'\s+version="[^"]*"', "", line)
        if version:
            line = line.replace(f'package="{name}"', f'package="{name}" version="{version}"', 1)
        return line

    return re.sub(r'^.*\bpackage="[^"]+".*$', one, text, flags=re.M), changed


def correct(path, text, found, present, measured=None):
    """Return the manifest text with its `provides` matching `present`, and
    the change as a sentence."""
    measured = measured or {}
    were = declared(text, top=True)["provides"]
    shipped = {name for name, paths in found.items() if any(p in present for p in paths)}
    gone = [name for name in were if name in found and name not in shipped]
    came = sorted(name for name in shipped if name not in were)
    if gone or came:
        if LINE.search(text):
            sys.exit(f"probe.py: {path} writes `provides` on a line; write it as a block")
        lines = [f'    "{name}" witness="{next(p for p in found[name] if p in present)}"\n'
                 for name in came]
        block = BLOCK.search(text)
        if block:
            kept = [line for line in block.group(1).splitlines(keepends=True)
                    if not any(re.match(rf'\s*"{re.escape(name)}"(\s|$)', line) for name in gone)]
            body = "".join(kept + lines)
            text = text[:block.start()] + (f"provides {{\n{body}}}\n" if body else "") + text[block.end():]
        else:
            first = re.search(r"^(imports|base)\s", text, re.M)
            if not first:
                sys.exit(f"probe.py: {path} has no `imports` or `base` node to put `provides` before")
            text = text[:first.start()] + f"provides {{\n{''.join(lines)}}}\n\n" + text[first.start():]
    text, revised = set_versions(text, measured)
    said = []
    if gone:
        said.append("loses " + ", ".join(f"`{name}`" for name in gone))
    if came:
        said.append("gains " + ", ".join(f"`{name}`" for name in came))
    kept = [f"`{package}` {measured[package]}" for package in revised if measured.get(package)]
    if kept:
        said.append("records " + ", ".join(kept))
    dropped = [f"`{package}`" for package in revised if not measured.get(package)]
    if dropped:
        said.append("drops the version of " + ", ".join(dropped))
    if not said:
        return text, ""
    return text, f"`{path}` `provides` " + " and ".join(said)


def main(argv):
    if argv[1:2] == ["list"] and len(argv) == 2:
        bases, components = library()
        for base in bases:
            paths = sorted({p for held in witnesses(base, bases, components).values() for p in held})
            measured_packages = sorted(set(packages(bases[base]).values()))
            print("|".join([base, reference(bases[base]), family(bases[base]) or "-",
                            " ".join(paths) or "-", " ".join(measured_packages) or "-"]))
        return
    if argv[1:2] != ["correct"] or len(argv) < 3:
        sys.exit(__doc__)
    bases, components = library()
    base = argv[2]
    if base not in bases:
        sys.exit(f"probe.py: no base component at {COMPONENTS / base}")
    present = []
    measured = {}
    args = argv[3:]
    while args:
        arg = args.pop(0)
        if arg == "--version":
            pair = args.pop(0) if args else ""
            package, _, version = pair.partition("=")
            if package:
                measured[package] = version
        else:
            present.append(arg)
    manifest = COMPONENTS / base / "manifest.kdl"
    text, said = correct(manifest, bases[base], witnesses(base, bases, components),
                         set(present), measured)
    if said:
        manifest.write_text(text)
        print(said)


if __name__ == "__main__":
    main(sys.argv)
