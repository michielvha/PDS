function Install-Minikube {
<#
.SYNOPSIS
    Installs Minikube on Windows if it is not already installed.

.DESCRIPTION
    The `Install-Minikube` function downloads and installs Minikube on Windows.
    It creates a directory at 'C:\minikube', downloads the latest Minikube executable,
    and adds the directory to the system PATH if it's not already there.

.EXAMPLE
    Install-Minikube

    This example installs Minikube on the Windows system and ensures it's available in the PATH.

.NOTES
    Author: itmvha
    Requires: Administrator privileges to modify system PATH.
    Alternative: You can also install Minikube using Chocolatey with 'choco install minikube'

.LINK
    https://minikube.sigs.k8s.io/
    Learn more about Minikube for local Kubernetes development.
#>

    # or just use chocolatey `choco install minikube`
    New-Item -Path 'c:\' -Name 'minikube' -ItemType Directory -Force
    Invoke-WebRequest -OutFile 'c:\minikube\minikube.exe' -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing
    $oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
    if ($oldPath.Split(';') -inotcontains 'C:\minikube'){
      [Environment]::SetEnvironmentVariable('Path', $('{0};C:\minikube' -f $oldPath), [EnvironmentVariableTarget]::Machine)
    }
}