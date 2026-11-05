# Repository instructions

Read the personal conventions at
https://github.com/vhco-pro/docs/blob/0e52f51f01b84eda75a976763c42d8ec0a07b544/AGENTS.md
and follow the task routes there before implementation. Use this full revision for every linked convention and guide.

Read `conventions/coding.md` for code and `conventions/documentation.md` plus `guides/humanize-prose.md` for documentation and other prose. For features, read `conventions/feature-documents.md`. For CI and releases, read `conventions/delivery.md` and `knowledge/shared-delivery.md`. For container work, also read `conventions/containers.md`. Onboarding follows `guides/onboard-a-repository.md`.

Load only the relevant pages. If a required source is inaccessible, report it and stop. Preserve local instructions and report conflicts with shared conventions. vh-adlc owns the lifecycle procedure; the pinned docs supply engineering rules.

## Local constraints

- Keep platform code under `bash/`, `pwsh/`, and `darwin/`, with Debian packaging under `packaging/`.
- Reuse existing helpers and preserve public function names unless the accepted work requires a change.
- Update `changelog.md` when changing the repository.
- Test platform behavior on the relevant operating system. Syntax checks or stubs alone do not prove installation or authentication works.
- Run bootstrap and installer checks in disposable environments. They can change packages, shell files, sudo policy, and Git credentials.
- Preserve unrelated edits and worktrees. Do not run installers against the development host as a verification shortcut.
- Feature documents use the default location, `docs/internal/plans/`. Create the directory when the first feature document needs it.

## Existing checks

From the repository root:

```bash
make -C packaging help
bash -n bash/debian/deploy/bootstrap.sh
bash -n packaging/bin/pds
```

The packaging Makefile also has `lint`, `validate`, and `test` targets. They need ShellCheck, nFPM, and Docker as applicable. `test` builds a package and installs it in a container. The existing `lint` target does not reliably fail on library ShellCheck errors; do not report it as complete coverage. PowerShell checks are not yet wired into CI.

These commands and limitations were inspected during onboarding preparation. Check execution results for the current change before claiming verification. Adding this entry point does not certify existing code against the shared conventions.
