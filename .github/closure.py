#!/usr/bin/env python3
"""Print the named components and everything they require, for one family.

An image that holds only a diff can fail on an unmet requirement, so the
closure adds a provider for each requirement. Run from the library root.

    closure.py <family> <base> <name>...
    closure.py --split <family> <base> <name>...
    closure.py --features

`--split` prints `<image> <component>` lines for the collection leg. Image 0
holds the named components with one provider of each capability. Each later
image holds alternative providers, closed over their requires.

`--features` prints every component that a collection leg may list. A base is
the image's `base` entry. An optioned component path names a directory whose
components are its alternatives. A collection leg lists the optioned component
and never the directory or an alternative.

A requirement that no component here provides is left alone. The base provides
some, such as `rechunking`. In the plain form, requirements print before the
component that needs them.

`create image` seeds the base component's requirements into every image, so the
closure covers them too. The base component declares a `base` reference that,
with its `version` default, matches `<base>` without its digest.

A tree entry for a component that the tree already lists fails `buildc check`.
No listed component is printed. The requirements of that component are still
closed over. A component path resolves the default of the option it names.

A `key` node provides `<kind>-key`. A component without `targets` targets every
family.
"""

import re
import sys
from pathlib import Path

COMPONENTS = Path("components")
LISTS = ("provides", "requires")
# A property and its value form one token. The value never joins a node's string arguments.
TOKEN = re.compile(
    r'//[^\n]*|[^\s{};"=]+=(?:"(?:[^"\\]|\\.)*"|[^\s{};]+)|"(?:[^"\\]|\\.)*"|[{};\n]|[^\s{};"]+'
)
BASE = re.compile(r'^base\s+"([^"]+)"', re.M)
VERSION = re.compile(r'^option\s+"version"[^{]*\{[^}]*?^\s*default\s+"([^"]*)"', re.M | re.S)


def nodes(text):
    """Yield each KDL node of a manifest as its enclosing nodes, its name and
    its string arguments. Each enclosing node is its name and its string
    arguments. A line that ends in a backslash continues on the next line."""
    text = re.sub(r"\\[ \t]*\n", " ", text)
    stack, current = [], None
    for token in TOKEN.findall(text):
        if token.startswith("//"):
            continue
        if token in ("\n", ";", "{", "}") and current:
            yield current
        if token == "{":
            stack.append((current[1], current[2]) if current else ("", []))
        elif token == "}" and stack:
            stack.pop()
        if token in ("\n", ";", "{", "}"):
            current = None
        elif current is None:
            current = (tuple(stack), token.strip('"'), [])
        elif token.startswith('"'):
            current[2].append(token[1:-1])
    if current:
        yield current


def declared(text, top):
    """Return the names each list node declares, by kind. A list node writes
    its names on its line or as the children of its block. If `top` is set,
    then a node inside an `on` gate is not counted."""
    out = {kind: [] for kind in LISTS}
    for parents, name, args in nodes(text):
        if name in LISTS and args and (not top or not parents):
            out[name] += args
        elif parents and parents[-1][0] in LISTS and (not top or len(parents) == 1):
            out[parents[-1][0]].append(name)
    return out


MANIFEST = {
    "schema-version", "description", "oci-labels", "conforms", "targets", "hidden",
    "provides", "requires", "after", "removes", "overrides", "mode", "key",
    "secret", "arg", "helpers", "allow-verify", "refuses", "collects",
    "contributes", "fragment", "option", "variant", "default-variant", "asset",
    "permissions", "packages", "package-groups", "copr", "satisfies", "on", "base",
}


def kdl(text):
    """Return the nodes of a component file, each with its name, arguments and
    children.

    The CI installs nothing. This reads KDL without a library.
    """
    text = re.sub(r"\\[ \t]*\n", " ", text)
    root = {"name": "", "args": [], "children": []}
    stack, current = [root], None
    for token in TOKEN.findall(text):
        if token.startswith("//"):
            continue
        if token == "{":
            stack[-1]["children"].append(current or {"name": "", "args": [], "children": []})
            stack.append(stack[-1]["children"][-1])
            current = None
        elif token == "}":
            current = None
            if len(stack) > 1:
                stack.pop()
        elif token in ("\n", ";"):
            if current:
                stack[-1]["children"].append(current)
            current = None
        elif token.startswith('"'):
            if current is None:
                current = {"name": "", "args": [], "children": []}
            current["args"].append(token[1:-1])
        elif current is None:
            current = {"name": token, "args": [], "children": []}
        else:
            current["args"].append(token)
    if current:
        stack[-1]["children"].append(current)
    return root["children"]


def tree_paths(text, at, family, options):
    """Return every component path that one component lists.

    A bare child resolves below the current context. The context starts at the
    listing component's path. `component "<path>"` resolves its path against
    the current context. Its children resolve below the result. A path that
    starts with `/` resolves from the top. A `{option}` segment reads the
    option's default. A segment whose option has no default stays as written. A
    node under an `on` gate is read only for a family that the gate names. An
    empty family reads every gate. A returned path may name no component in the
    library.
    """
    out = set()

    def value(path):
        return re.sub(
            r"\{([a-z][a-z0-9-]*)\}",
            lambda match: options.get(match.group(1), match.group(0)),
            path,
        )

    def context(current, path):
        parts = [] if path.startswith("/") else [part for part in current.split("/") if part]
        for part in path.split("/"):
            if not part or part == ".":
                continue
            if part == "..":
                if parts:
                    parts.pop()
                continue
            parts.append(part)
        return "/".join(parts)

    def walk(node, current):
        name = node["name"]
        if name == "on":
            gate = set(node["args"])
            if family and gate and family not in gate:
                return
            for child in node["children"]:
                walk(child, current)
            return
        if name == "component":
            raw = value(node["args"][0]) if node["args"] else ""
            here = context(current, raw)
            if raw.rsplit("/", 1)[-1] not in ("", ".", ".."):
                out.add(here)
            for child in node["children"]:
                walk(child, here)
            return
        if name in MANIFEST or node["args"]:
            return
        if node["children"] and all(
            child["name"] == "" or (child["name"] == "remove" and child["args"])
            for child in node["children"]
        ):
            return
        here = f"{current}/{name}".strip("/")
        out.add(here)
        for child in node["children"]:
            walk(child, here)

    for node in kdl(text):
        walk(node, at)
    return out


def is_base(text):
    return BASE.search(text) is not None


def manifests(components):
    """Yield the path, the manifest and the text of each component under
    `components`. A directory whose name starts with a dot holds none."""
    for manifest in sorted(components.rglob("component.kdl")):
        if any(part.startswith(".") for part in manifest.relative_to(components).parts[:-1]):
            continue
        yield manifest.parent.relative_to(components).as_posix(), manifest, manifest.read_text()


def reference(text):
    """Return the image that a base component builds from at the default of
    its `version` option."""
    version = VERSION.search(text)
    return BASE.search(text).group(1).replace("{version}", version.group(1) if version else "")


def base_needs(components, image):
    """Return the capabilities, the requirements and the component paths of the
    one base component built from `image`."""
    wanted = image.split("@", 1)[0]
    matches = []
    for name, manifest, text in manifests(components):
        if not is_base(text) or reference(text) != wanted:
            continue
        # A base lists the components every image on it needs. The base's paths
        # are read for every family.
        _, provides, requires, paths = read(manifest, name, "")
        matches.append((manifest.parent, (sorted(provides), sorted(requires), sorted(paths))))
    if not matches:
        sys.exit(f"closure.py: no base component under {components} builds from {wanted}")
    if len(matches) > 1:
        paths = ", ".join(str(directory) for directory, _ in matches)
        sys.exit(f"closure.py: {wanted} is the image of more than one base component: {paths}")
    return matches[0][1]


def targets(component, family):
    return not component[0] or family in component[0]


def read(path, name, family):
    text = path.read_text()
    targeted, provides, options = set(), set(), {}
    for parents, node, args in nodes(text):
        if node == "default" and args and parents and parents[-1][0] == "option":
            options[parents[-1][1][0]] = args[0]
            continue
        if parents or not args:
            continue
        if node == "targets":
            targeted.update(args)
        elif node == "key":
            provides.add(args[0] + "-key")
    lists = declared(text, top=False)
    provides.update(lists["provides"])
    return targeted, provides, set(lists["requires"]), tree_paths(text, name, family, options)


def listed(components, base_paths, names):
    """Return every component that the base or one of `names` lists,
    followed transitively."""
    out = set()
    todo = list(base_paths)
    for name in names:
        if name in components:
            todo.extend(components[name][3])
    while todo:
        path = todo.pop()
        if path in out or path not in components:
            continue
        out.add(path)
        todo.extend(components[path][3])
    return out


def split(components, family, names):
    """Split the named components into images that each hold one provider of
    anything. A component joins the first image that provides none of what it
    provides."""
    images = []
    for name in sorted(n for n in names if n in components and targets(components[n], family)):
        for members, held in images:
            if not components[name][1] & held:
                members.append(name)
                held.update(components[name][1])
                break
        else:
            images.append(([name], set(components[name][1])))
    groups = [members for members, _ in images] or [[]]
    changed = True
    while changed:
        changed = False
        first = groups[0]
        held = set().union(*(components[m][1] for m in first))
        for name in list(first):
            wants = components[name][2] - held
            home = next((i for i, other in enumerate(groups[1:], 1)
                         if any(wants & components[m][1] for m in other)), None)
            if home is not None:
                first.remove(name)
                groups[home].append(name)
                changed = True
                break
    return groups


def option_dirs(components):
    """Return the directory part of every optioned component path."""
    out = set()
    for _, _, text in manifests(components):
        for node in kdl(text):
            if node["name"] != "component" or not node["args"] or "{" not in node["args"][0]:
                continue
            prefix = node["args"][0].split("{", 1)[0].lstrip("/")
            if prefix:
                out.add(prefix)
    return out


def contracts(text):
    """Return the files one component collects and the files it contributes."""
    collects, contributes = set(), set()
    for node in kdl(text):
        if node["name"] == "collects" and node["args"]:
            collects.add(node["args"][0])
        elif node["name"] == "contributes" and node["args"]:
            contributes.add(node["args"][0])
    return collects, contributes


def pair_collectors(groups, texts):
    """Move each contributor into the group that holds the collector of its file.

    A collector and its contributors must be in one leg. Otherwise the image
    built from that leg lacks the files the contributors add.
    """
    collects, contributes = {}, {}
    for name in texts:
        files, given = contracts(texts[name])
        collects[name] = files
        contributes[name] = given
    files = sorted({held for given in contributes.values() for held in given})
    holders = {
        file: [i for i, group in enumerate(groups) if any(file in collects[n] for n in group)]
        for file in files
    }
    for i, group in enumerate(groups):
        for name in list(group):
            belongs = any(holders[file] and i in holders[file] for file in contributes[name])
            wanted = any(holders[file] for file in contributes[name])
            if wanted and not belongs:
                group.remove(name)
        for name, given in contributes.items():
            if any(holders[file] and i in holders[file] for file in given):
                if name not in group:
                    group.append(name)


def features(components):
    """Return the components a collection leg may list."""
    prefixes = option_dirs(components)
    return [
        name
        for name, _, text in manifests(components)
        if not is_base(text) and not any(name.startswith(prefix) for prefix in prefixes)
    ]


def main(argv):
    if argv[1:2] == ["--features"]:
        for name in features(COMPONENTS):
            print(name)
        return
    splitting = argv[1:2] == ["--split"]
    argv = [argv[0]] + argv[2:] if splitting else argv
    if len(argv) < 3:
        sys.exit(__doc__)
    family, base, wanted = argv[1], argv[2], argv[3:]

    components = {}
    declared_provides = {}
    for name, manifest, text in manifests(COMPONENTS):
        if is_base(text):
            continue
        components[name] = read(manifest, name, family)
        declared_provides[name] = set(components[name][1])
        # The component name is one of its capabilities. A requirement can name the component.
        components[name][1].add(name)

    needs = base_needs(COMPONENTS, base)
    base_provides = set(needs[0])

    def covered(name):
        # A component that declares no capability still adds its packages. The
        # base never covers that component.
        provides = declared_provides[name]
        return bool(provides) and provides <= base_provides

    wanted = [name for name in wanted if name not in components or not covered(name)]
    if not splitting:
        for name in close(components, family, needs, wanted):
            print(name)
        return
    first, *rest = split(components, family, wanted)
    texts = {
        name: manifest.read_text()
        for name, manifest, _ in manifests(COMPONENTS)
        if name in components
    }
    pair_collectors([first] + rest, texts)
    for name in close(components, family, needs, first):
        print(f"0 {name}")
    for index, alternates in enumerate(rest, 1):
        for name in close(components, family, needs, alternates):
            print(f"{index} {name}")


def close(components, family, needs, wanted):
    _, base_requires, base_paths = needs
    provider = {}
    for name in sorted(components):
        provides = components[name][1]
        if not targets(components[name], family):
            continue
        for capability in sorted(provides):
            provider.setdefault(capability, name)

    for name in wanted:
        if name in components and targets(components[name], family):
            for capability in components[name][1]:
                provider[capability] = name

    order, seen, brought = [], set(), set()

    def bring(path):
        if path not in components:
            return
        brought.add(path)
        for capability in components[path][1]:
            provider[capability] = path
        visit(path)

    def visit(name):
        if name in seen:
            return
        seen.add(name)
        for path in sorted(components[name][3]):
            bring(path)
        for capability in sorted(components[name][2]):
            needed = provider.get(capability)
            if needed and needed != name:
                visit(needed)
        order.append(name)

    for path in base_paths:
        bring(path)
    for capability in base_requires:
        seeded = provider.get(capability)
        if seeded:
            visit(seeded)
    for name in wanted:
        if name in components and targets(components[name], family):
            visit(name)
    return [name for name in order if name not in brought]


if __name__ == "__main__":
    main(sys.argv)
