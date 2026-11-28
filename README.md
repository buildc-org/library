# The buildc-org library

The library holds the core components for buildc. A component's path is its
name: the first segment is the role and the second is the implementation. The
tree in `repo.kdl` reads as the path, so
`container-environment { runtime { podman } }` is
`container-environment/runtime/podman`.

The core library carries the common, non-opinionated components and the audit
claims. The opinionated and non-free components live in the
`buildc-contrib` organisation, one repository per type; the component library
is `buildc-contrib/components` at its repository root.

The groups are:

- `base-image/` — the distribution bases.
- `boot/`, `bootc-base/`, `kernel/` — the boot chain, the bootc additions and
  the kernel helpers.
- `build-environment/`, `buildc/`, `flatpak/` — the build and package
  primitives.
- `container-environment/`, `virt/` — the container runtimes and builders, and
  the virtual machine stack.
- `cli/`, `dev/`, `desktop/` — the common command line, Git and the desktop
  environments.
- `network/`, `security/`, `login/`, `compliance/` — the network diagnostics,
  security, access and audit components.
- `storage/`, `observability/` — known gaps.

`CONTRIBUTING.md` holds the acceptance criteria.
