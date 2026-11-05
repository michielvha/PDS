# README backlog review

Conventions: `vhco-pro/docs@0e52f51f01b84eda75a976763c42d8ec0a07b544`; prose edited with `guides/humanize-prose.md`.

The source inventory uses PDS commit `04c8deee5973252099d90df10a2e69565f728016`. The root README describes platform coverage and usage. Remaining work has the trackers below; existing code is not treated as proof of successful installation on every platform.

## Backlog disposition

| Earlier README item | Current evidence and tracker |
| --- | --- |
| Repository workflow | [#36](https://github.com/michielvha/PDS/issues/36) tracks pinned vh-adlc entry points. |
| Add testing and linting | The [APT workflow](../../../.github/workflows/build-apt-package.yml) already invokes lint and package checks. [#37](https://github.com/michielvha/PDS/issues/37) tracks blocking library lint and PowerShell checks. |
| Improve error handling | [Bootstrap stages](../../../bash/debian/deploy/bootstrap.sh) can hide intermediate failures. [#38](https://github.com/michielvha/PDS/issues/38) tracks failure propagation. |
| Safe bootstrap reruns | [configure_zsh](../../../bash/common/shell/zsh.sh) replaces user configuration. [#39](https://github.com/michielvha/PDS/issues/39) tracks preservation; [#32](https://github.com/michielvha/PDS/issues/32) retains Linux installation and authentication validation. |
| Single Linux bootstrap | The [Debian entry point](../../../bash/debian/deploy/bootstrap.sh) and [CLI dispatch](../../../packaging/bin/pds) exist. Fedora and Arch equivalents remain in [#40](https://github.com/michielvha/PDS/issues/40) and [#41](https://github.com/michielvha/PDS/issues/41). |
| Remove packaging/lib duplicates | The directory is absent at the inventory commit; installer wrappers exist in [the Debian HashiCorp helpers](../../../bash/debian/software/hashicorp.sh). No new issue. |
| Resolve bash/module | The [legacy directory](../../../bash/module/) still contains functions and public source paths. [#42](https://github.com/michielvha/PDS/issues/42) tracks its disposition and compatibility. |
| Windows taskbar setup | No implementation found in the Windows script inventory. [#43](https://github.com/michielvha/PDS/issues/43) tracks the feature. |
| Win11Debloat integration | The [setup script](../../../pwsh/scripts/main.ps1) has a placeholder. The [service-disabling helper](../../../pwsh/module/Public/System/Remove-WindowsBloat.ps1) is different behavior. [#44](https://github.com/michielvha/PDS/issues/44) tracks the integration. |
| Custom Windows logging | [Set-Log](../../../pwsh/module/Public/utils/Set-Log.ps1) exists. [#45](https://github.com/michielvha/PDS/issues/45) tracks its failure path and setup error reporting. |
| Diagnostics and machine information | [Diagnostics](../../../pwsh/module/Public/diagnostics/) and [system helpers](../../../pwsh/module/Public/System/) exist. Use [#2](https://github.com/michielvha/PDS/issues/2) for the accurate documentation inventory; additional unspecified diagnostics do not define an implementation task. |
| Kubernetes dependency checks | [Install-AzureKubeCLI](../../../pwsh/module/Public/Kubernetes/Install-KubeCLI.ps1) already checks for Azure CLI. Automatic installation remains a separate behavior choice. [#2](https://github.com/michielvha/PDS/issues/2) covers correcting the command-name documentation and checking exports against the module loader. |
| Kubernetes aliases | [Set-Kubectl](../../../pwsh/module/Public/Kubernetes/Set-Kubectl.ps1) writes the alias and completer. Extension work remains in [#6](https://github.com/michielvha/PDS/issues/6). |
| macOS support | [Installation](../../../darwin/install.sh) and [shell helpers](../../../darwin/functions.sh) exist. Describe their scope rather than calling the whole platform planned. |

Existing [#2](https://github.com/michielvha/PDS/issues/2), [#5](https://github.com/michielvha/PDS/issues/5), [#6](https://github.com/michielvha/PDS/issues/6), and [#32](https://github.com/michielvha/PDS/issues/32) retain their work. This review closes none of them.

## Ideas awaiting scope

- Shell history synchronisation: decide whether this belongs in PDS or a separate project. Go was an idea in the old README, not an accepted implementation choice.
- UniFi server setup: choose the target OS, hosting method, and configuration scope.
- AltStore or other sideload tooling: choose the platform and workflow. This is separate from UniFi server setup.

The old reminder to check a phone for more ideas contained no concrete requirement to migrate.
