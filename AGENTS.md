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

## Retained PDS project instructions

# Copilot Instructions for PDS (Portable Deploy Suite)

## Project Overview

**PDS (Portable Deploy Suite)** is a cross-platform automation toolkit designed to streamline software installation and system configuration across Linux, Windows, and macOS environments.

### Platform Coverage

- **Linux**: Comprehensive packaging solution with full automation capabilities
- **Windows**: PowerShell module and script-based deployment system
- **macOS (Darwin)**: Basic setup scripts (currently in early development)

## Core Development Principles

### 🎯 Think Before You Code
- **Plan First**: Always understand the problem completely before implementing
- **Justify Every Addition**: Don't add code just to add code - every line must serve a purpose
- **Question Complexity**: If it feels complex, it probably is - find a simpler way

### 🏗️ Architecture Guidelines

#### Modularity
- Each component should have a single, well-defined responsibility
- Components should be independently testable and maintainable
- Avoid monolithic solutions - break down into logical, reusable modules

#### Loose Coupling
- Minimize dependencies between modules
- Use interfaces and abstractions where appropriate
- Components should be easily replaceable without affecting others

#### Focus & Clarity
- Each function/script should have a clear, specific purpose
- Avoid feature creep - stick to the core mission
- Code should be self-documenting through clear naming and structure

### 📋 Repository Conventions

**ALWAYS follow existing patterns and conventions in the repository:**

1. **File Structure**: Maintain the established directory hierarchy
2. **Naming Conventions**: Follow the naming patterns already in use
3. **Code Style**: Match the existing code formatting and style
4. **Documentation**: Keep documentation consistent with current format
5. **Platform Organization**: Respect the separation between `bash/`, `pwsh/`, and `darwin/` directories

### 🚫 What NOT to Do

- **Don't over-engineer**: Simple, working solutions are preferred over complex, "clever" ones
- **Don't duplicate functionality**: Reuse existing code where possible
- **Don't break existing patterns**: Follow established conventions religiously
- **Don't add unnecessary dependencies**: Keep the tool portable and lightweight
- **Don't create code without purpose**: Every addition must solve a real problem

### ✅ Best Practices

#### Code Quality
- Write self-explanatory code with clear variable and function names
- Add comments only when the "why" isn't obvious from the code
- Test thoroughly across target platforms
- Handle errors gracefully and provide meaningful feedback

#### Maintainability
- Keep functions small and focused
- Use consistent error handling patterns
- Document any platform-specific behaviors or limitations
- Ensure changes are backward compatible when possible
- When you make a change, update or create changelog.md in the root directory just to keep a record of any changes made.

#### Portability
- Consider platform differences from the start
- Test on actual target platforms, not just development environment
- Use platform-appropriate tools and conventions
- Avoid hardcoded paths or platform assumptions

## Development Workflow

1. **Analyze**: Understand the requirement and existing codebase
2. **Plan**: Design the solution keeping modularity and simplicity in mind
3. **Implement**: Write clean, focused code following repository conventions
4. **Test**: Verify functionality across relevant platforms
5. **Document**: Update relevant documentation if needed
6. **Review**: Ensure the solution maintains codebase quality and consistency

## Remember

The goal is to create a **lean, maintainable, and reliable** deployment suite. Every decision should be evaluated against these principles:

- Does this solve a real problem?
- Is this the simplest solution that works?
- Does this follow existing patterns?
- Will this be maintainable in 6 months?
- Does this add unnecessary complexity?

**When in doubt, choose simplicity over cleverness, and consistency over innovation.**
