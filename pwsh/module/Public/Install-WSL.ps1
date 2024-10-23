Function Install-WSL {
    <#
    .SYNOPSIS
        Installs WSL (Windows Subsystem for Linux) distributions.

    .DESCRIPTION
        The `Install-WSL` function provides a wrapper for installing WSL distributions on Windows.
        It optionally accepts an array of distro names to install. If no parameters are passed,
        it simply lists available distributions online. If distributions are passed as parameters,
        it will attempt to install each one using the `wsl --install` command.

    .PARAMETER distros
        An optional array of WSL distro names that you wish to install. Each distro name should
        match one of the names listed by `wsl --list --online`. If not provided, the function
        will only list the available distros.

    .EXAMPLE
        $distros = @("Ubuntu", "Debian")
        Install-WSL -d $distros

        This example installs the `Ubuntu` and `Debian` distributions using WSL.

    .EXAMPLE
        Install-WSL -d(istros) Alpine, Kali-Linux, Debian

        This example installs the distribution if it is available in the online list.

    .NOTES
        Author: MKTHEPLUGG
        Requires: WSL to be enabled on the system. Is enabled by default on any newer windows build (w11+)
        This function uses the `wsl --install` command to install the specified distributions.

    .LINK
        https://docs.microsoft.com/en-us/windows/wsl/install
        Learn more about installing and configuring WSL.
    #>

    param (
        [Alias("d")]
        [string[]]$distros  # Accepts an array of distro names
    )

    Write-Output "This function is a wrapper for installing WSL. Call it with any distro listed below."
    wsl --list --online

    if ($distros) {
        foreach ($distro in $distros) {
            try {
                Write-Output "`nAttempting to install $distro..."
                wsl --install -d $distro
            } catch {
                Write-Output "An error occured while installing ${distro} :" $_
            }
        }
    }
}

