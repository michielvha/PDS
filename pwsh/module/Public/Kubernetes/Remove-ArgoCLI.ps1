Function Remove-ArgoCLI {
    <#
    .SYNOPSIS
        Removes the ArgoCD CLI if it was installed via the PDS Module.

    .DESCRIPTION
        This function checks if the ArgoCD CLI was installed in the user's local bin directory and removes it if found.

    .PARAMETER None
        This function does not take any parameters.

    .EXAMPLE
        Remove-ArgoCLI
        This command will remove the ArgoCD CLI from the local bin directory if it was installed via the PDS Module.

    .NOTES
        This function is part of the PDS Module and is used to manage the installation of the ArgoCD CLI.

    .LINK
        https://argoproj.github.io/argo-cd/
    #>

    # function definiton
    $Argo = "$env:USERPROFILE\AppData\Local\bin\argocd.exe"
    if (Test-Path $Argo) {
        Remove-Item -Path $Argo -Recurse -Force
    }
    else {
        Write-Output "$Argo directory doesn't exist. ArgoCD CLI was not installed via PDS Module."
    }
}