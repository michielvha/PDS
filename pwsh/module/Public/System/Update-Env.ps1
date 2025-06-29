function Update-Env{
    <#
    .SYNOPSIS
        Refreshes the current PowerShell session's environment variables from the Windows registry.

    .DESCRIPTION
        The Refresh-Env function reloads all environment variables from the Windows registry,
        including system-wide (`HKLM:\System\CurrentControlSet\Control\Session Manager\Environment`)
        and user-specific (`HKCU:\Environment`) variables. 

        It also merges the `Path` environment variable from both system and user scopes to ensure
        newly added directories are available without requiring a new shell session.

    .PARAMETER None
        This function does not take any parameters.

    .EXAMPLE
        Refresh-Env
        Refreshes the environment variables in the current PowerShell session, 
        applying any recent changes made via registry modifications or external software installations.

    .EXAMPLE
        $env:MY_TEST_VAR = "OldValue"
        Set-ItemProperty -Path "HKCU:\Environment" -Name "MY_TEST_VAR" -Value "NewValue" -Force
        Refresh-Env
        $env:MY_TEST_VAR
        # Output: "NewValue"
        # This example demonstrates how a registry change to an environment variable is applied immediately.

    .OUTPUTS
        None. The function does not return any values, but it updates the session's environment variables.

    .NOTES
        - Requires administrative privileges if modifying system environment variables.
        - This function does not permanently modify environment variables; it only updates the session.
        - The function does not handle changes made via `SetX` or `Environment.SetEnvironmentVariable` with the `Machine` scope.

        Author: Michiel VH
        Date:   February 2025
    .LINK
        https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setx
    #>
    Write-Host "Refreshing environment variables from registry..." -ForegroundColor Cyan

    # Load System-wide environment variables
    $systemEnvPath = "HKLM:\System\CurrentControlSet\Control\Session Manager\Environment"
    $systemEnv = Get-ItemProperty -Path $systemEnvPath
    foreach ($key in $systemEnv.PSObject.Properties.Name) {
        if ($key -ne "Path") {
            [System.Environment]::SetEnvironmentVariable($key, $systemEnv.$key, [System.EnvironmentVariableTarget]::Process)
        }
    }

    # Load User-specific environment variables
    $userEnvPath = "HKCU:\Environment"
    $userEnv = Get-ItemProperty -Path $userEnvPath
    foreach ($key in $userEnv.PSObject.Properties.Name) {
        if ($key -ne "Path") {
            [System.Environment]::SetEnvironmentVariable($key, $userEnv.$key, [System.EnvironmentVariableTarget]::Process)
        }
    }

    # Special handling for PATH - merge both System and User
    $systemPath = $systemEnv.Path -split ";" | Where-Object { $_ -ne "" }
    $userPath = $userEnv.Path -split ";" | Where-Object { $_ -ne "" }
    $combinedPath = ($systemPath + $userPath) -join ";"

    [System.Environment]::SetEnvironmentVariable("Path", $combinedPath, [System.EnvironmentVariableTarget]::Process)

    Write-Host "Environment variables refreshed successfully!" -ForegroundColor Green
}

# Debug Version
function Update-EnvDebug {
    Write-Host "Refreshing environment variables from registry..." -ForegroundColor Cyan

    # Load System-wide environment variables
    $systemEnvPath = "HKLM:\System\CurrentControlSet\Control\Session Manager\Environment"
    $systemEnv = Get-ItemProperty -Path $systemEnvPath

    Write-Host "`n[System Environment Variables]:" -ForegroundColor Yellow
    foreach ($key in $systemEnv.PSObject.Properties.Name) {
        if ($key -ne "Path") {
            [System.Environment]::SetEnvironmentVariable($key, $systemEnv.$key, [System.EnvironmentVariableTarget]::Process)
            Write-Host "Updated: $key = $($systemEnv.$key)" -ForegroundColor Green
        }
    }

    # Load User-specific environment variables
    $userEnvPath = "HKCU:\Environment"
    $userEnv = Get-ItemProperty -Path $userEnvPath

    Write-Host "`n[User Environment Variables]:" -ForegroundColor Yellow
    foreach ($key in $userEnv.PSObject.Properties.Name) {
        if ($key -ne "Path") {
            [System.Environment]::SetEnvironmentVariable($key, $userEnv.$key, [System.EnvironmentVariableTarget]::Process)
            Write-Host "Updated: $key = $($userEnv.$key)" -ForegroundColor Green
        }
    }

    # Special handling for PATH - merge both System and User
    $systemPath = $systemEnv.Path -split ";" | Where-Object { $_ -ne "" }
    $userPath = $userEnv.Path -split ";" | Where-Object { $_ -ne "" }
    $combinedPath = ($systemPath + $userPath) -join ";"

    [System.Environment]::SetEnvironmentVariable("Path", $combinedPath, [System.EnvironmentVariableTarget]::Process)

    Write-Host "`n[Path Variable Merged]:" -ForegroundColor Yellow
    Write-Host "System PATH: $([System.Environment]::GetEnvironmentVariable('Path', 'Machine'))" -ForegroundColor Blue
    Write-Host "User PATH: $([System.Environment]::GetEnvironmentVariable('Path', 'User'))" -ForegroundColor Blue
    Write-Host "Updated PATH: $combinedPath" -ForegroundColor Green

    Write-Host "`nEnvironment variables refreshed successfully!" -ForegroundColor Green
}
