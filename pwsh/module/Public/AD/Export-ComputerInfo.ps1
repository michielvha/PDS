function Export-ComputerInfo {
    <#
    .SYNOPSIS
        Exports Active Directory computer information to CSV or Excel format.

    .DESCRIPTION
        The Export-ComputerInfo function retrieves all computer objects from Active Directory 
        and exports their information (name, location, last logon date) to either a CSV or Excel file.
        
        The function sorts computers by their last seen date in descending order (most recent first).
        For Excel export, the ImportExcel module will be automatically installed if not available.

    .PARAMETER Path
        Specifies the output file path. The file extension determines the export format.
        Use .csv for CSV export or .xlsx for Excel export.

    .PARAMETER Format
        Specifies the export format. Valid values are 'CSV' or 'Excel'.
        If not specified, the format is determined by the file extension in the Path parameter.

    .PARAMETER SearchBase
        Specifies the distinguished name (DN) of the starting point for the search.
        Default is to search the entire domain.

    .PARAMETER Filter
        Specifies a custom filter for selecting computers.
        Default is to retrieve all computer objects.

    .PARAMETER PassThru
        Returns the computer objects after the operation completes.

    .EXAMPLE
        Export-ComputerInfo -Path "C:\temp\ComputerInfo.csv"
        
        Exports all computer information to a CSV file.

    .EXAMPLE
        Export-ComputerInfo -Path "C:\temp\ComputerInfo.xlsx"
        
        Exports all computer information to an Excel file.

    .EXAMPLE
        Export-ComputerInfo -Path "C:\temp\Computers.csv" -Format CSV
        
        Explicitly specifies CSV format for export.

    .EXAMPLE
        Export-ComputerInfo -Path "C:\temp\ServersOnly.xlsx" -Filter "Name -like '*SRV*'"
        
        Exports only computers with 'SRV' in their name to an Excel file.

    .EXAMPLE
        Export-ComputerInfo -Path "C:\temp\OUComputers.csv" -SearchBase "OU=Computers,DC=contoso,DC=com"
        
        Exports computers from a specific organizational unit to a CSV file.

    .NOTES
        For Excel export, the ImportExcel module is required and will be installed automatically.
        Requires appropriate permissions to read computer objects in Active Directory.
        
        Output is sorted by Last Seen date in descending order (most recent first).
        
        Author: Michiel VH

    .LINK
        Get-ADComputer
        Export-Csv
        Export-Excel
        https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-adcomputer

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('CSV', 'Excel')]
        [string]$Format,

        [Parameter()]
        [string]$SearchBase,

        [Parameter()]
        [string]$Filter = "*",

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        # Import ActiveDirectory module if not already loaded
        if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
            try {
                Import-Module ActiveDirectory -ErrorAction Stop
                Write-Verbose "ActiveDirectory module imported successfully"
            }
            catch {
                throw "Failed to import ActiveDirectory module. Please ensure RSAT tools are installed."
            }
        }

        # Determine format if not specified
        if (-not $Format) {
            $Extension = [System.IO.Path]::GetExtension($Path).ToLower()
            switch ($Extension) {
                '.csv' { $Format = 'CSV' }
                '.xlsx' { $Format = 'Excel' }
                default {
                    throw "Unable to determine format from file extension '$Extension'. Please specify -Format parameter or use .csv or .xlsx extension."
                }
            }
        }

        # Import ImportExcel module for Excel export
        if ($Format -eq 'Excel') {
            if (-not (Get-Module -ListAvailable -Name ImportExcel -ErrorAction SilentlyContinue)) {
                try {
                    Write-Host "Installing ImportExcel module..." -ForegroundColor Yellow
                    Install-Module -Name ImportExcel -Scope CurrentUser -Force -ErrorAction Stop
                    Write-Verbose "ImportExcel module installed successfully"
                }
                catch {
                    throw "Failed to install ImportExcel module: $($_.Exception.Message)"
                }
            }

            if (-not (Get-Module -Name ImportExcel -ErrorAction SilentlyContinue)) {
                try {
                    Import-Module ImportExcel -ErrorAction Stop
                    Write-Verbose "ImportExcel module imported successfully"
                }
                catch {
                    throw "Failed to import ImportExcel module: $($_.Exception.Message)"
                }
            }
        }

        # Ensure output directory exists
        $OutputDirectory = [System.IO.Path]::GetDirectoryName($Path)
        if (-not (Test-Path -Path $OutputDirectory)) {
            try {
                New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
                Write-Verbose "Created output directory: $OutputDirectory"
            }
            catch {
                throw "Failed to create output directory '$OutputDirectory': $($_.Exception.Message)"
            }
        }
    }

    process {
        try {
            $GetADComputerParams = @{
                Filter = $Filter
                Properties = @('Name', 'DistinguishedName', 'LastLogonDate')
                ErrorAction = 'Stop'
            }

            if ($SearchBase) {
                $GetADComputerParams.SearchBase = $SearchBase
            }

            Write-Verbose "Retrieving Active Directory computers with filter: $Filter"
            $Computers = Get-ADComputer @GetADComputerParams
            
            if ($Computers.Count -eq 0) {
                Write-Warning "No computers found matching the specified criteria"
                return
            }

            Write-Host "Found $($Computers.Count) computer(s) to export" -ForegroundColor Green

            # Initialize the output array
            $Output = foreach ($Computer in $Computers) {
                # Create a custom object for each computer
                [pscustomobject]@{
                    'Computer Name' = $Computer.Name
                    'Location' = $Computer.DistinguishedName
                    'Last Seen' = $Computer.LastLogonDate
                }
            }

            # Sort the output based on 'Last Seen' column in descending order (most recent first)
            $OutputSorted = $Output | Sort-Object 'Last Seen' -Descending

            # Export based on format
            switch ($Format) {
                'CSV' {
                    $OutputSorted | Export-Csv -Path $Path -NoTypeInformation -ErrorAction Stop
                    Write-Host "Computer information exported to CSV: $Path" -ForegroundColor Green
                }
                'Excel' {
                    $OutputSorted | Export-Excel -Path $Path -AutoSize -ErrorAction Stop
                    Write-Host "Computer information exported to Excel: $Path" -ForegroundColor Green
                }
            }

            if ($PassThru) {
                return $OutputSorted
            }
        }
        catch {
            Write-Error "Failed to export computer information: $($_.Exception.Message)"
        }
    }
}
