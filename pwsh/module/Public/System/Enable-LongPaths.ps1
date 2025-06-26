function Enable-LongPaths {
    $keyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    $valueName = "LongPathsEnabled"
    $valueData = 1

    try {
        # Check if the key exists; if not, create it
        if (!(Test-Path $keyPath)) {
            New-Item -Path $keyPath -Force | Out-Null
            Write-Output "Registry path created: $keyPath"
        }

        # Set the LongPathsEnabled key to 1
        Set-ItemProperty -Path $keyPath -Name $valueName -Value $valueData
        Write-Output "Long paths enabled successfully."
    }
    catch {
        Write-Error "Failed to set LongPathsEnabled: $_"
    }
}
