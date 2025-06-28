---
external help file: PDS-help.xml
Module Name: PDS
online version: https://kubernetes.io/docs/tasks/tools/
Learn more about `kubectl` and how it is used to manage Kubernetes clusters.
schema: 2.0.0
---

# Install-KubeCLI

## SYNOPSIS
Installs \`kubectl\` and \`kubelogin\` if they are not already installed on the system.

## SYNTAX

```
Install-KubeCLI
```

## DESCRIPTION
The \`Install-KubeCLI\` function checks if both \`kubectl\` and \`kubelogin\` are installed on the system by attempting to retrieve their version information.
If either tool is missing, the function uses the Azure CLI (\`az\`) to install both tools via \`az aks install-cli\`.
If both tools are already installed, their version information is displayed.

## EXAMPLES

### EXAMPLE 1
```
Install-KubeCLI
```

This command checks for the installation of both \`kubectl\` and \`kubelogin\`.
If they are not found, it installs them using the Azure CLI.
If they are already installed, it prints their current version.

## PARAMETERS

## INPUTS

## OUTPUTS

## NOTES
Author: Michiel Van Haegenborgh
Requires: Azure CLI (\`az\`) to be installed on the system for installing \`kubectl\` and \`kubelogin\`.
This function assumes that \`az aks install-cli\` will be used to manage the Kubernetes CLI tools.

## RELATED LINKS

[https://kubernetes.io/docs/tasks/tools/
Learn more about `kubectl` and how it is used to manage Kubernetes clusters.](https://kubernetes.io/docs/tasks/tools/
Learn more about `kubectl` and how it is used to manage Kubernetes clusters.)

[https://kubernetes.io/docs/tasks/tools/
Learn more about `kubectl` and how it is used to manage Kubernetes clusters.]()

[https://github.com/Azure/kubelogin
Learn more about `kubelogin`, a tool for Azure Kubernetes Service (AKS) authentication.]()

