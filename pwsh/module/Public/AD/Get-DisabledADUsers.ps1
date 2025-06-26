function Get-DisabledADUsers {
    <#
    .SYNOPSIS
        Retrieves and displays disabled Active Directory user accounts.

    .DESCRIPTION
        The Get-DisabledADUsers function retrieves all disabled user accounts from Active Directory
        with detailed information about each account. Results can be displayed in various formats
        including a grid view, formatted table, or as raw objects for further processing.
        
        This function automatically imports the required ActiveDirectory module if it's not already loaded.

    .PARAMETER SearchBase
        Specifies the distinguished name (DN) of the starting point for the search.
        Default is to search the entire domain.

    .PARAMETER Properties
        Specifies the user properties to retrieve. 
        Default includes common properties like SamAccountName, DisplayName, DistinguishedName, etc.

    .PARAMETER ShowGridView
        If specified, displays the results in a grid view window.
        Default is $false.

    .PARAMETER Format
        Specifies how to format the output.
        Valid values are: 'Table', 'List', 'Grid', 'None'
        Default is 'Table'.

    .EXAMPLE
        Get-DisabledADUsers
        
        Retrieves all disabled AD users and displays them in a formatted table.

    .EXAMPLE
        Get-DisabledADUsers -ShowGridView
        
        Retrieves all disabled AD users and displays them in a grid view.

    .EXAMPLE
        Get-DisabledADUsers -Format List
        
        Retrieves all disabled AD users and displays them in a list format.

    .EXAMPLE
        Get-DisabledADUsers -SearchBase "OU=Users,OU=Company,DC=contoso,DC=com"
        
        Retrieves disabled AD users from the specified organizational unit.

    .EXAMPLE
        $disabledUsers = Get-DisabledADUsers -Format None
        $disabledUsers | Export-Csv -Path "C:\Reports\DisabledUsers.csv" -NoTypeInformation
        
        Retrieves disabled AD users as objects and exports them to a CSV file.

    .NOTES
        - Requires the ActiveDirectory module
        - Make sure you have appropriate permissions to query AD
        - You might want to run this on a domain controller or computer with the RSAT tools installed
    #>
    
    param (
        [string]$SearchBase,
        [string[]]$Properties = @(
            'SamAccountName', 'DisplayName', 'UserPrincipalName',
            'GivenName', 'Surname', 'Description', 'DistinguishedName',
            'Enabled', 'LastLogonDate', 'whenCreated', 'whenChanged',
            'Title', 'Department', 'Office', 'Manager'
        ),
        [switch]$ShowGridView,
        [ValidateSet('Table', 'List', 'Grid', 'None')]
        [string]$Format = 'Table'
    )

    # Check if ActiveDirectory module is loaded and import it if necessary
    if (-not (Get-Module -Name ActiveDirectory)) {
        Write-Host "Importing ActiveDirectory module..." -ForegroundColor Cyan
        try {
            Import-Module -Name ActiveDirectory -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to import ActiveDirectory module. Make sure RSAT Tools are installed."
            return
        }
    }

    Write-Host "Retrieving disabled AD users..." -ForegroundColor Cyan
    
    # Build parameters for Get-ADUser
    $adParams = @{
        Filter = {Enabled -eq $false}
        Properties = $Properties
    }
    
    # Add SearchBase if specified
    if ($SearchBase) {
        $adParams.SearchBase = $SearchBase
    }
    
    # Execute the AD query
    try {
        $disabledUsers = Get-ADUser @adParams | 
            Select-Object -Property $Properties,
                @{Name="Manager Name"; Expression={
                    if ($_.Manager) {
                        try { (Get-ADUser -Identity $_.Manager -ErrorAction SilentlyContinue).Name } 
                        catch { "Unknown" }
                    } else { "None" }
                }},
                @{Name="Account Age (Days)"; Expression={
                    if ($_.whenCreated) {
                        [math]::Round((New-TimeSpan -Start $_.whenCreated -End (Get-Date)).TotalDays)
                    } else { "Unknown" }
                }},
                @{Name="Days Since Modified"; Expression={
                    if ($_.whenChanged) {
                        [math]::Round((New-TimeSpan -Start $_.whenChanged -End (Get-Date)).TotalDays)
                    } else { "Unknown" }
                }}
    }
    catch {
        Write-Error "Error retrieving disabled AD users: $_"
        return
    }

    # Check if any users are found
    if (-not $disabledUsers -or $disabledUsers.Count -eq 0) {
        Write-Host "No disabled AD users found." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($disabledUsers.Count) disabled users." -ForegroundColor Green

    # Output results based on format
    if ($ShowGridView -or $Format -eq 'Grid') {
        $disabledUsers | Sort-Object -Property SamAccountName | 
            Out-GridView -Title "Disabled AD Users ($($disabledUsers.Count) accounts)"
    }
    elseif ($Format -eq 'Table') {
        $disabledUsers | Format-Table -Property SamAccountName, DisplayName, LastLogonDate, 'Account Age (Days)', 'Days Since Modified', Description -AutoSize
    }
    elseif ($Format -eq 'List') {
        $disabledUsers | Format-List -Property SamAccountName, DisplayName, UserPrincipalName, 
            Description, Title, Department, 'Manager Name', LastLogonDate, 
            whenCreated, whenChanged, 'Account Age (Days)', 'Days Since Modified'
    }

    # Always return the objects for pipeline processing
    return $disabledUsers
}
