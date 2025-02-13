Function Set-Kubectl {
    <#
    .SYNOPSIS

    Quick function to install krew and stern

    .DESCRIPTION

    This function will check if krew and stern are installed, if not it will install them.

    .EXAMPLE

    Set-Kubectl

    .NOTES

    pretty straight forward.

    .LINK

    kubectl plugin docs:
    https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

    krew - package manager for kubectl plugins:
    https://krew.sigs.k8s.io/
    #>


    # function definiton
    $Krew = kubectl krew version
    if (!$Krew) {
        choco install krew -y
    }

    $Stern = kubectl stern -v
    if (!$Stern) {
        kubectl krew install stern
    }
}