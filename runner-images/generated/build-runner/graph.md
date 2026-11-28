# `build-runner` capability graph

GENERATED FILE, do not edit.

An arrow points from a provider to what needs it, dotted for `after`,
which orders the build without requiring anything. Layers build left to
right.
A thick arrow points from a component to what it lists or imports.

```mermaid
graph LR
    base["registry.fedoraproject.org/fedora:45"]
    m0["build-environment/dnf"]
    m1["os-release"]
    m2["container-environment/runtime/podman"]
    m3["container-environment/builder/buildah"]
    m4["build-runner"]
    m0 -->|"build-environment"| m2
    base ==>|"imports"| m0
    m4 ==>|"lists"| m1
    m4 ==>|"lists"| m2
    m4 ==>|"lists"| m3
```

## Capabilities

| Name | Kind | Provided by | Required by | After |
|---|---|---|---|---|
| `build-environment` | capability | `build-environment/dnf` | `container-environment/runtime/podman` |  |
| `buildah` | file | `container-environment/builder/buildah` |  |  |
| `container-builder` | capability | `container-environment/builder/buildah` |  |  |
| `container-runtime` | capability | `container-environment/runtime/podman` |  |  |
| `crun` | file | `container-environment/runtime/podman` |  |  |
| `os-release` | capability | `os-release` |  |  |
| `package-manager/dnf5` | capability | `base` |  |  |
| `podman` | file | `container-environment/runtime/podman` |  |  |

## Imports

| Component | By | How |
|---|---|---|
| `build-environment/dnf` | `base-image/fedora-container` | imports |
| `os-release` | `build-runner` | lists |
| `container-environment/runtime/podman` | `build-runner` | lists |
| `container-environment/builder/buildah` | `build-runner` | lists |
