function Set-DockerAlias {
    <#
    .SYNOPSIS
    Sets functions for common Docker commands in the PowerShell profile for persistence.

    .DESCRIPTION
    The `Set-DockerAlias` function creates functions for common Docker commands and writes them to the PowerShell profile to ensure they persist across sessions. The function checks if they are already set and only sets them if they are not defined. This is the same as adding aliasses in linux.

    The functions created by this script are:
    - `dcu` for `docker compose up -d`
    - `d` for `docker`
    - `dcd` for `docker compose down`

    .EXAMPLE
    Set-DockerAlias

    .author: itmvha
    #>

    $profilePath = $PROFILE

    $aliases = @(
        @{Name="d"; Command="docker"}
        @{Name="dcu"; Command="docker compose up -d"}
        @{Name="dcd"; Command="docker compose down"}
    )

    foreach ($alias in $aliases) {
        $aliasName = $alias.Name
        $aliasCommand = $alias.Command

        # Check if the function is already defined in the profile
        if (!(Get-Content $profilePath -ErrorAction SilentlyContinue | Select-String -Pattern "function $aliasName")) {
            # Add the function to the profile
            $functionDefinition = "function $aliasName { $aliasCommand }"
            Add-Content -Path $profilePath -Value $functionDefinition
            Write-Output "Function $aliasName added to profile successfully."
        } else {
            Write-Output "Function $aliasName is already defined in the profile."
        }
    }

    Write-Output "Reload your profile or restart PowerShell for changes to take effect."
}
