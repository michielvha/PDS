function Remove-DisabledUsersFromMailAddressList {
    <#
    .SYNOPSIS
        Hides disabled Active Directory users from Exchange address lists.

    .DESCRIPTION
        The Remove-DisabledUsersFromMailAddressList function retrieves all disabled user accounts 
        from Active Directory and sets their msExchHideFromAddressLists attribute to $true, 
        effectively hiding them from Exchange address lists and Global Address Lists (GAL).
        
        This function is useful for maintaining clean address lists by automatically hiding 
        inactive user accounts while preserving the accounts themselves for potential reactivation.
        
        This function automatically imports the required ActiveDirectory module if it's not already loaded.

    .PARAMETER WhatIf
        Shows what would happen if the function runs without actually making any changes.

    .PARAMETER Confirm
        Prompts for confirmation before making changes to each user account.

    .PARAMETER PassThru
        Returns the modified user objects after the operation completes.

    .EXAMPLE
        Remove-DisabledUsersFromMailAddressList
        
        Hides all disabled AD users from Exchange address lists.

    .EXAMPLE
        Remove-DisabledUsersFromMailAddressList -WhatIf
        
        Shows which disabled users would be hidden from address lists without making any changes.

    .EXAMPLE
        Remove-DisabledUsersFromMailAddressList -Confirm
        
        Prompts for confirmation before hiding each disabled user from address lists.

    .EXAMPLE
        $ModifiedUsers = Remove-DisabledUsersFromMailAddressList -PassThru
        
        Hides disabled users from address lists and returns the modified user objects.

    .NOTES
        This function modifies the msExchHideFromAddressLists attribute for disabled user accounts.
        Requires appropriate permissions to modify user objects in Active Directory.
        
        Author: Michiel VH

    .LINK
        Get-ADUser
        Set-ADObject
        https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-aduser
        https://docs.microsoft.com/en-us/powershell/module/activedirectory/set-adobject

    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
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
            Write-Verbose "Retrieving disabled Active Directory users..."
            $DisabledUsers = Get-ADUser -Filter {Enabled -eq $false} -ErrorAction Stop
            
            if ($DisabledUsers.Count -eq 0) {
                Write-Warning "No disabled users found in Active Directory"
                return
            }

            Write-Host "Found $($DisabledUsers.Count) disabled user(s) to hide from address lists" -ForegroundColor Green

            foreach ($User in $DisabledUsers) {
                if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Hide from Exchange address lists")) {
                    try {
                        Set-ADObject -Identity $User.DistinguishedName -Replace @{msExchHideFromAddressLists=$true} -ErrorAction Stop
                        Write-Verbose "Successfully hidden user '$($User.SamAccountName)' from address lists"
                        
                        if ($PassThru) {
                            # Return the modified user object
                            Get-ADUser -Identity $User.SamAccountName -Properties msExchHideFromAddressLists
                        }
                    }
                    catch {
                        Write-Error "Failed to hide user '$($User.SamAccountName)' from address lists: $($_.Exception.Message)"
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to retrieve disabled users: $($_.Exception.Message)"
        }
    }
}