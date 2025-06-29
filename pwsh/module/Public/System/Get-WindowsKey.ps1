function Get-WindowsKey {
    <#
    .SYNOPSIS
        Retrieves the Windows product key and OS information from local or remote computers.

    .DESCRIPTION
        The Get-WindowsKey function retrieves the Windows product key by decoding the DigitalProductId
        from the registry. It also collects additional operating system information such as OS version,
        build number, architecture, and registration details.
        
        This function can target local or remote computers and returns comprehensive information
        about each system's Windows installation.

    .PARAMETER ComputerName
        Specifies the target computers to query. Default is the local computer.
        Can accept multiple computer names or IP addresses.

    .PARAMETER Credential
        Specifies the credential object to use for authentication when connecting to remote computers.
        Not required for local computer access or when using current credentials.

    .EXAMPLE
        Get-WindowsKey
        
        Retrieves the Windows product key and OS information from the local computer.

    .EXAMPLE
        Get-WindowsKey -ComputerName "Server01", "Server02"
        
        Retrieves the Windows product key and OS information from two remote servers.

    .EXAMPLE
        Get-WindowsKey -ComputerName "Server01" -Credential (Get-Credential)
        
        Prompts for credentials and uses them to retrieve the Windows product key from a remote server.

    .EXAMPLE
        "Server01", "Server02" | Get-WindowsKey | Export-Csv -Path "C:\WindowsKeys.csv" -NoTypeInformation
        
        Retrieves Windows product keys from multiple servers and exports the results to a CSV file.

    .NOTES
        Original concept by Jakob Bindslet (jakob@bindslet.dk)
        Enhanced with modern PowerShell techniques and improved error handling
        this makes the function faster and more robust.
        
        The digital product key decoding algorithm works on Windows XP through Windows 11.
        Remote access requires appropriate permissions and network connectivity.

        Author: Michiel VH
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [Alias("Computer", "ComputerName", "HostName")]
        [string[]]$Targets = ".",
        
        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Begin {
        Write-Verbose "Starting Get-WindowsKey function"
        $hklm = 2147483650  # HKEY_LOCAL_MACHINE
        $regPath = "Software\Microsoft\Windows NT\CurrentVersion"
        $regValue = "DigitalProductId"
        
        # Character set for the Windows product key
        $charsArray = "B","C","D","F","G","H","J","K","M","P","Q","R","T","V","W","X","Y","2","3","4","6","7","8","9"
    }
    
    Process {
        Foreach ($target in $Targets) {
            Write-Verbose "Processing computer: $target"
            try {
                # Create hashtable for WMI parameters
                $wmiParams = @{
                    ComputerName = $target
                    ErrorAction = 'Stop'
                }
                
                # Add credentials if specified
                if ($Credential) {
                    $wmiParams.Add('Credential', $Credential)
                }
                
                # Check if target is local machine or remote
                if ($target -eq "." -or $target -eq "localhost" -or $target -eq $env:COMPUTERNAME) {
                    # Access registry directly on local machine for better performance
                    Write-Verbose "Accessing local registry"
                    try {
                        $regKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
                        $regSubKey = $regKey.OpenSubKey($regPath)
                        if ($regSubKey) {
                            $digitalProductId = $regSubKey.GetValue($regValue)
                            if ($digitalProductId) {
                                $binArray = $digitalProductId[52..66]
                            } else {
                                Write-Warning "DigitalProductId value not found in registry on $target"
                                continue
                            }
                        } else {
                            Write-Warning "Windows NT registry key not found on $target"
                            continue
                        }
                    } catch {
                        Write-Warning "Error accessing local registry on $target`: $_"
                        continue
                    }
                } else {
                    # Use WMI for remote registry access
                    Write-Verbose "Accessing remote registry via WMI"
                    try {
                        $wmi = Get-WmiObject -Class "StdRegProv" -Namespace "root\default" @wmiParams
                        $data = $wmi.GetBinaryValue($hklm, $regPath, $regValue)
                        
                        if (-not $data -or -not $data.uValue) {
                            Write-Warning "Failed to retrieve product key data from $target"
                            continue
                        }
                        
                        $binArray = ($data.uValue)[52..66]
                    } catch {
                        Write-Warning "Error connecting to $target`: $_"
                        continue
                    }
                }
                
                # Decode the product key
                $productKey = $null
                
                try {
                    # Decrypt base24 encoded binary data
                    For ($i = 24; $i -ge 0; $i--) {
                        $k = 0
                        For ($j = 14; $j -ge 0; $j--) {
                            $k = $k * 256 -bxor $binArray[$j]
                            $binArray[$j] = [math]::Truncate($k / 24)
                            $k = $k % 24
                        }
                        $productKey = $charsArray[$k] + $productKey
                        If (($i % 5 -eq 0) -and ($i -ne 0)) {
                            $productKey = "-" + $productKey
                        }
                    }
                } catch {
                    Write-Warning "Error decoding product key on $target`: $_"
                    $productKey = "DECODE-ERROR"
                }
                
                # Get OS Details
                try {
                    # Get OS info using CIM on newer systems or WMI as fallback
                    $osInfoParams = $wmiParams.Clone()
                    $win32os = Get-CimInstance -ClassName Win32_OperatingSystem @osInfoParams -ErrorAction Stop
                } catch {
                    try {
                        $win32os = Get-WmiObject -Class Win32_OperatingSystem @wmiParams
                    } catch {
                        Write-Warning "Error retrieving OS information from $target`: $_"
                        # Create minimal object if OS info collection fails
                        $win32os = [PSCustomObject]@{
                            Caption = "Unknown"
                            CSDVersion = "Unknown"
                            OSArchitecture = "Unknown"
                            BuildNumber = "Unknown"
                            RegisteredUser = "Unknown"
                            SerialNumber = "Unknown"
                        }
                    }
                }
                
                # Create and return the output object with OS and product key information
                [PSCustomObject]@{
                    Computer = $target
                    Caption = $win32os.Caption
                    Version = $win32os.Version
                    CSDVersion = $win32os.CSDVersion
                    OSArchitecture = $win32os.OSArchitecture
                    BuildNumber = $win32os.BuildNumber
                    RegisteredTo = $win32os.RegisteredUser
                    ProductID = $win32os.SerialNumber
                    ProductKey = $productKey
                    InstallDate = if ($win32os.InstallDate) { 
                        [System.Management.ManagementDateTimeConverter]::ToDateTime($win32os.InstallDate)
                    } else { $null }
                }
            } catch {
                Write-Error "An unexpected error occurred while processing $target`: $_"
            }
        }
    }
    
    End {
        Write-Verbose "Get-WindowsKey function completed"
    }
}
