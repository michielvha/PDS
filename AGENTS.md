# Repository instructions

Read the personal conventions at
https://github.com/vhco-pro/docs/blob/d8f07c9dd69038375a535af8ad586086688f85ab/AGENTS.md
and follow the task routes there before implementation.

For code, read `conventions/coding.md` at that revision. For features, read
`conventions/feature-documents.md` and `conventions/delivery.md`. For command-line
interfaces, also read `conventions/terminal-output.md`. For documentation and
commit messages, read `conventions/documentation.md` and `guides/humanize-prose.md`.
When onboarding, read `guides/onboard-a-repository.md`.

Load only the relevant pages. If they cannot be read, report that and stop.
Keep the existing repository-specific rules in
[.github/copilot-instructions.md](.github/copilot-instructions.md). Report
conflicts rather than silently overriding either source.

## Local commands and constraints

- Keep platform-specific code under `bash/`, `pwsh/` and `darwin/` as appropriate.
- Update `changelog.md` for changes, including documentation changes.
- Preserve unrelated working-tree and index changes.
- Host inspection does not authorize filesystem repair, cache deletion, service
  installation, backup changes or deployment.
- Do not add AI attribution to commits or documents.
