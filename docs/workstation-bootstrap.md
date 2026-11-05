# Debian and Ubuntu workstation bootstrap

`bootstrap_workstation` runs four setup stages. The implementation is in [`bash/debian/deploy/bootstrap.sh`](../bash/debian/deploy/bootstrap.sh), with a wrapper in the packaged `pds` CLI.

Full Linux validation is still tracked in [issue #32](https://github.com/michielvha/PDS/issues/32). Each stage can be selected independently. The scripts do not establish that every stage is safe to rerun: the base stage replaces `~/.zshrc`, and installer failures can be hidden by later successful commands.

## Run from a checkout

```bash
git clone https://github.com/michielvha/PDS.git
cd PDS
source bash/debian/deploy/bootstrap.sh
bootstrap_workstation repos
```

The `repos` stage requires GitHub CLI authentication. Choose another stage explicitly, or run `bootstrap_workstation` without arguments for all four stages.

The bootstrap loads helper files from `/usr/share/pds` when available, or downloads them from GitHub. Loading the entry point from a checkout does not make every helper local or offline.

For the existing remote loading path:

```bash
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/deploy/bootstrap.sh)
bootstrap_workstation repos
```

If the package is installed:

```bash
pds bootstrap          # all four stages
pds bootstrap repos    # clone missing repositories
```

## Stages

| Stage | Actions |
| --- | --- |
| `base` | System upgrade; core packages; passwordless sudo; bat; Zsh, Zi, and Powerlevel10k. Replaces `~/.zshrc` and changes the default shell. |
| `stack` | Docker, Go, Node, kubectl, Azure CLI, AWS CLI, VS Code, and Claude Code installers |
| `github` | GitHub CLI, Git Credential Manager, authentication, commit identity, and credential routing |
| `repos` | Clone non-archived repositories for the configured owners into the workspace |

The entry point rejects hosts without `/etc/debian_version`. Fedora and Arch have separate scripts but no equivalent staged workstation bootstrap.

## Configuration

Export overrides before loading the bootstrap entry point.

| Variable | Default | Purpose |
| --- | --- | --- |
| `PDS_WORKSPACE` | `~/code/personal` | Repository workspace |
| `PDS_GIT_IDENTITY` | `michielvha` | GitHub login and identity configuration name |
| `PDS_GIT_NAME` | `michielvha` | Git commit author name |
| `PDS_GIT_EMAIL` | `michielvh@outlook.com` | Git commit author email |
| `PDS_GITHUB_OWNERS` | `michielvha vhco-pro` | Space-separated repository owners |
| `PDS_REF` | `main` | Ref used when fetching bootstrap helper files |
| `PDS_LIB_DIR` | `/usr/share/pds` | Preferred installed helper directory |

`PDS_REF` controls fallback fetches made by the bootstrap helper loader. It does not pin every download or nested installer in the repository.

## Git identity and credentials

The `github` stage configures commit identity by workspace directory. An `includeIf` entry in `~/.gitconfig` loads an identity file from `~/.gitconfig.d/` for repositories under the configured workspace. Owner-specific GitHub credential entries select the login separately from the commit author.

`show_git_identity` inspects the identity configuration. `verify_github_credentials` checks credential routing for the owners. `sync_github_credentials` copies the selected GitHub CLI token into Git's credential store; rerun it after an authentication refresh if Git uses the wrong account.

The Linux Git Credential Manager and GPG/pass path still needs verification under [issue #32](https://github.com/michielvha/PDS/issues/32).

## Windows references

The root [README](../readme.md#references) retains links to the external Windows projects that informed the setup scripts.
