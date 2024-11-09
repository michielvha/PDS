function Set-DockerAlias {
    <#
    .SYNOPSIS
    Sets aliases for the Docker commands if they are not already set.

    .DESCRIPTION
    The `Set-DockerAlias` function sets aliases for common Docker commands to simplify their usage. The function checks if the aliases are already set and only sets them if they are not defined.

    The aliases set by this function are:
    - `dc` for `docker compose up -d`
    - `dc` for `docker compose`
    - `dcd` for `docker compose down`

    .EXAMPLE
    Set-DockerAlias

    .author: itmvha
    #>


$aliases =  @(
        @{Name="dc"; Command="docker compose up -d"}
        @{Name="dc"; Command="docker compose"}
        @{Name="dcd"; Command="docker compose down"}
        )

    foreach ($alias in $aliases) {
        $aliasName = $alias.Name
        $aliasCommand = $alias.Command
            # Check if the alias is already set
        if (!(Get-Alias -Name $aliasName -ErrorAction SilentlyContinue)) {
            # Set the alias for the Docker command
            Set-Alias -Name $aliasName -Value $aliasCommand
            Write-Output "Alias for $aliasName command set successfully."
        } else {
            Write-Output "Alias for $aliasName command is already set."
        }
    }

}