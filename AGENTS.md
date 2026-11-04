# Repository instructions

Read the personal conventions at
https://github.com/vhco-pro/docs/blob/0e52f51f01b84eda75a976763c42d8ec0a07b544/AGENTS.md
and follow the task routes there before implementation.

For code, read conventions/coding.md. For feature work, read
conventions/feature-documents.md and conventions/delivery.md. For documentation,
read conventions/documentation.md and guides/humanize-prose.md. For CI and releases,
read knowledge/shared-delivery.md too. Load only the relevant pages at that revision.
If a required page is unavailable, report it and stop. Preserve local instructions;
report conflicts instead of silently overriding either source.

## Local commands and constraints

- `make -C packaging build` builds the Debian package with nFPM. It changes generated
  files under packaging; retain needed artifacts before a clean rebuild.
- `make -C packaging test-image-provisioning` builds/installs the package and runs its
  image-provisioning checks in disposable Ubuntu. Never run those root filesystem tests
  directly on the development host.
- Keep PDS a standalone function library for ordinary host setup. Loading installed
  libraries must not run installers or download dependencies; work starts at explicit calls.
- Builders selects PDS functions. PDS does not own Proxmox bootstrap or image sealing,
  and must not acquire a Proxmox dependency.
- Preserve Zi and the existing Powerlevel10k preset/plugin configuration. Image users
  retain the selected per-user first-login downloads.
- Keep the active image-provisioning dependency isolated from the Cloudflare-host feature
  and unrelated worktrees. Preserve existing staged/unstaged work; no reset, stash or cleanup.
- Commits stay local until delivery is authorized. Merges and releases require separate
  owner approval; neither tests nor a passing review grant that approval.
