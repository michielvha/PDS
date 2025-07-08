function Set-ProxyAddress {
    <#
    .SYNOPSIS
        Sets proxy addresses for Active Directory users based on their UserPrincipalName.

    .DESCRIPTION
        The Set-ProxyAddress function retrieves all users from Active Directory and adds their 
        current UserPrincipalName as a proxy address (smtp:) to their account. This is particularly 
        useful when changing domain names but users still need to be reachable on their old email address.
        
        The function adds the UserPrincipalName as a secondary SMTP proxy address, preserving 
        existing proxy addresses. This ensures mail routing continues to work for both old and new 
        email addresses during domain transitions.
        
        This function automatically imports the required ActiveDirectory module if it's not already loaded.

    .PARAMETER SearchBase
        Specifies the distinguished name (DN) of the starting point for the search.
        Default is to search the entire domain.

    .PARAMETER Filter
        Specifies a custom filter for selecting users. 
        Default is to process all users with a UserPrincipalName.

    .PARAMETER WhatIf
        Shows what would happen if the function runs without actually making any changes.

    .PARAMETER Confirm
        Prompts for confirmation before making changes to each user account.

    .PARAMETER PassThru
        Returns the modified user objects after the operation completes.

    .EXAMPLE
        Set-ProxyAddress
        
        Adds proxy addresses for all Active Directory users based on their UserPrincipalName.

    .EXAMPLE
        Set-ProxyAddress -WhatIf
        
        Shows which users would have proxy addresses added without making any changes.

    .EXAMPLE
        Set-ProxyAddress -SearchBase "OU=Users,OU=Company,DC=contoso,DC=com"
        
        Sets proxy addresses for users in the specified organizational unit.

    .EXAMPLE
        Set-ProxyAddress -Filter "Department -eq 'IT'" -Confirm
        
        Sets proxy addresses for users in the IT department with confirmation prompts.

    .EXAMPLE
        $ModifiedUsers = Set-ProxyAddress -PassThru
        
        Sets proxy addresses and returns the modified user objects.

    .NOTES
        This function modifies the proxyAddresses attribute for user accounts.
        Requires appropriate permissions to modify user objects in Active Directory.
        
        The function adds proxy addresses as secondary SMTP addresses (smtp:) not primary (SMTP:).
        Existing proxy addresses are preserved - this function only adds new ones.
        
        Author: Michiel VH

    .LINK
        Get-ADUser
        Set-ADUser
        https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-aduser
        https://docs.microsoft.com/en-us/powershell/module/activedirectory/set-aduser

    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter()]
        [string]$SearchBase,

        [Parameter()]
        [string]$Filter = "UserPrincipalName -like '*'",

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
    }

    process {
        try {
            $GetADUserParams = @{
                Filter = $Filter
                Properties = @('SamAccountName', 'UserPrincipalName', 'proxyAddresses')
                ErrorAction = 'Stop'
            }

            if ($SearchBase) {
                $GetADUserParams.SearchBase = $SearchBase
            }

            Write-Verbose "Retrieving Active Directory users with filter: $Filter"
            $Users = Get-ADUser @GetADUserParams
            
            if ($Users.Count -eq 0) {
                Write-Warning "No users found matching the specified criteria"
                return
            }

            Write-Host "Found $($Users.Count) user(s) to process for proxy address updates" -ForegroundColor Green

            foreach ($User in $Users) {
                if ([string]::IsNullOrWhiteSpace($User.UserPrincipalName)) {
                    Write-Warning "Skipping user '$($User.SamAccountName)' - UserPrincipalName is empty"
                    continue
                }

                $ProxyAddress = "smtp:$($User.UserPrincipalName)"
                
                # Check if proxy address already exists
                if ($User.proxyAddresses -contains $ProxyAddress) {
                    Write-Verbose "User '$($User.SamAccountName)' already has proxy address '$ProxyAddress'"
                    continue
                }

                if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Add proxy address '$ProxyAddress'")) {
                    try {
                        Set-ADUser -Identity $User.SamAccountName -Add @{proxyAddresses = $ProxyAddress} -ErrorAction Stop
                        Write-Verbose "Successfully added proxy address '$ProxyAddress' to user '$($User.SamAccountName)'"
                        
                        if ($PassThru) {
                            # Return the modified user object
                            Get-ADUser -Identity $User.SamAccountName -Properties SamAccountName, UserPrincipalName, proxyAddresses
                        }
                    }
                    catch {
                        Write-Error "Failed to add proxy address for user '$($User.SamAccountName)': $($_.Exception.Message)"
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to retrieve users: $($_.Exception.Message)"
        }
    }
}