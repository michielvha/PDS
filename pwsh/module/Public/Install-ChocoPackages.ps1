function Install-ChocoPackages {
    <#
    .SYNOPSIS
        Installs a list of Chocolatey packages from an array, if they are not already installed.

    .DESCRIPTION
        The `Install-ChocoPackagesFromFile` function takes an array of package names and attempts to install each one using Chocolatey. If the package is already installed, Chocolatey will skip reinstallation. The function outputs the packages to be installed and provides status updates as it processes each package.

    .PARAMETER packagesToInstall
        An array of package names that you wish to install via Chocolatey. Each package name should correspond to a valid Chocolatey package.

    .EXAMPLE
        $packages = @("git", "nodejs", "python")
        Install-ChocoPackagesFromFile -packagesToInstall $packages

        This example installs the `git`, `nodejs`, and `python` packages using Chocolatey. If any of the packages are already installed, Chocolatey will skip them.

    .EXAMPLE
        Install-ChocoPackagesFromFile -packagesToInstall @("docker", "vscode")

        This command installs `docker` and `vscode` if they are not already present on the system.

    .NOTES
        Author: MKTHEPLUGG
        Requires: Chocolatey to be installed on the system.
        This function uses the `choco install` command and runs it with the `-y` flag to bypass prompts.

    .LINK
        https://chocolatey.org/
        Learn more about Chocolatey and package management.
    #>

    param (
        [Alias("p")]
        [string[]]$packagesToInstall  # Accepts an array of package names
    )

    Write-Host "The following packages will be installed if not already present:"
    $packagesToInstall

    foreach ($packageName in $packagesToInstall) {
        Write-Host "`nAttempting to install $packageName..."
        choco install $packageName -y
    }
}
