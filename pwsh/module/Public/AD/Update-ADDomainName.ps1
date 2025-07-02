function Update-ADDomainName {
    <#
    .SYNOPSIS
        Changes the domain name for all users in Active Directory and configures email forwarding.

    .DESCRIPTION
        The Update-ADDomainName function handles the domain name change process in Active Directory.
        When an organization changes its domain name, this function performs the following tasks:
        
        1. Sets the old email address as a secondary SMTP proxy address to maintain email continuity
        2. Changes all user principal names (UPNs) from the old domain to the new domain
        3. Sets the new email address as the primary SMTP address

        This ensures a smooth transition during a domain name change while maintaining email
        functionality throughout the process.

    .PARAMETER OldDomain
        Specifies the old domain name (e.g., "contoso.com").
        This is the domain being replaced.

    .PARAMETER NewDomain
        Specifies the new domain name (e.g., "contoso.org").
        This is the domain that will replace the old domain.

    .PARAMETER UserFilter
        Optional filter to specify which users to process.
        By default, processes all users with UPNs containing the old domain.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs.
        The cmdlet doesn't run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .EXAMPLE
        Update-ADDomainName -OldDomain "old-domain.com" -NewDomain "new-domain.com"
        
        Updates all users' domain from old-domain.com to new-domain.com, preserving email continuity.

    .EXAMPLE
        Update-ADDomainName -OldDomain "contoso.local" -NewDomain "contoso.com" -UserFilter "Department -eq 'IT'"
        
        Updates only IT department users from contoso.local to contoso.com domain.

    .NOTES
        - Requires the Active Directory PowerShell module
        - Requires Domain Admin privileges
        - Should be run on a domain controller or system with proper permissions
        - Internet connection may be required if Azure AD sync is enabled
        - You should first register the new domain in local AD or Azure AD
        
        Author: Michiel VH
    #>
    
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$OldDomain,
        
        [Parameter(Mandatory=$true, Position=1)]
        [string]$NewDomain,
        
        [Parameter()]
        [string]$UserFilter
    )

    begin {
        # Check for AD module
        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            Write-Error "This function requires the Active Directory module. Please install RSAT and try again."
            return
        }

        # Ensure domain names are properly formatted
        if (-not $OldDomain.StartsWith("@")) { $OldDomain = "@$OldDomain" }
        if (-not $NewDomain.StartsWith("@")) { $NewDomain = "@$NewDomain" }

        # Create default filter if not provided
        if (-not $UserFilter) {
            $domainFilter = $OldDomain.TrimStart('@')
            $UserFilter = "UserPrincipalName -like '*$domainFilter'"
        }

        Write-Host "Starting domain name change from $($OldDomain.TrimStart('@')) to $($NewDomain.TrimStart('@'))" -ForegroundColor Cyan
        Write-Host "This process will:" -ForegroundColor Cyan
        Write-Host "  1. Set proxy addresses for all users to maintain email continuity" -ForegroundColor Yellow
        Write-Host "  2. Change user principal names (UPNs) to the new domain" -ForegroundColor Yellow 
        Write-Host "  3. Set the new email address as primary SMTP address" -ForegroundColor Yellow

        $processedUsers = @()
    }

    process {
        # Get users from AD based on filter
        Write-Verbose "Retrieving users from Active Directory with filter: $UserFilter"
        $users = Get-ADUser -Filter $UserFilter -Properties SamAccountName, UserPrincipalName, ProxyAddresses

        if (-not $users -or $users.Count -eq 0) {
            Write-Warning "No users found matching filter: $UserFilter"
            return
        }

        Write-Host "Found $($users.Count) users to process" -ForegroundColor Cyan

        # STEP 1: Set proxy addresses for old email addresses
        Write-Host "`nSTEP 1: Setting secondary SMTP proxy addresses for old email addresses..." -ForegroundColor Cyan
        foreach ($user in $users) {
            $SamAccountName = $user.SamAccountName
            $UserPrincipalName = $user.UserPrincipalName
            $displayInfo = "$SamAccountName ($UserPrincipalName)"
            
            if ($PSCmdlet.ShouldProcess($displayInfo, "Add proxy address $UserPrincipalName")) {
                try {
                    Write-Verbose "Adding proxy address: smtp:$UserPrincipalName"
                    Set-ADUser $SamAccountName -Add @{proxyAddresses="smtp:$UserPrincipalName"} -ErrorAction Stop
                    Write-Host "  [OK] Added proxy address for $displayInfo" -ForegroundColor Green
                    $processedUsers += $user
                } catch {
                    Write-Error "  [ERROR] Failed to add proxy address for $displayInfo : $_"
                }
            }
        }
        
        # STEP 2: Change UPN for all users
        Write-Host "`nSTEP 2: Updating User Principal Names to new domain..." -ForegroundColor Cyan
        $localUsers = Get-ADUser -Filter "$UserFilter" -Properties userPrincipalName
        
        foreach ($user in $localUsers) {
            $SamAccountName = $user.SamAccountName
            $oldUPN = $user.UserPrincipalName
            $newUPN = $oldUPN.Replace($OldDomain, $NewDomain)
            $displayInfo = "$SamAccountName ($oldUPN -> $newUPN)"
            
            if ($PSCmdlet.ShouldProcess($displayInfo, "Update UPN")) {
                try {
                    Set-ADUser -Identity $user -UserPrincipalName $newUPN -ErrorAction Stop
                    Write-Host "  [OK] Updated UPN for $SamAccountName" -ForegroundColor Green
                } catch {
                    Write-Error "  [ERROR] Failed to update UPN for $displayInfo : $_"
                }
            }
        }
        
        # STEP 3: Set new email addresses as primary SMTP
        Write-Host "`nSTEP 3: Setting new email addresses as primary SMTP addresses..." -ForegroundColor Cyan
        $updatedUsers = Get-ADUser -Filter $UserFilter -Properties SamAccountName, UserPrincipalName
        
        foreach ($user in $updatedUsers) {
            $SamAccountName = $user.SamAccountName
            $UserPrincipalName = $user.UserPrincipalName
            $displayInfo = "$SamAccountName ($UserPrincipalName)"
            
            if ($PSCmdlet.ShouldProcess($displayInfo, "Set primary SMTP address")) {
                try {
                    Write-Verbose "Setting primary SMTP address: SMTP:$UserPrincipalName"
                    Set-ADUser $SamAccountName -Add @{proxyAddresses="SMTP:$UserPrincipalName"} -ErrorAction Stop
                    Write-Host "  [OK] Set primary SMTP address for $displayInfo" -ForegroundColor Green
                } catch {
                    Write-Error "  [ERROR] Failed to set primary SMTP address for $displayInfo : $_"
                }
            }
        }
    }

    end {
        Write-Host "`nDomain Name Change Summary:" -ForegroundColor Cyan
        Write-Host "  Old Domain: $($OldDomain.TrimStart('@'))" -ForegroundColor Yellow
        Write-Host "  New Domain: $($NewDomain.TrimStart('@'))" -ForegroundColor Green
        Write-Host "  Users processed: $($processedUsers.Count)" -ForegroundColor Cyan
        
        Write-Host "`nNext Steps:" -ForegroundColor Magenta
        Write-Host "  1. Run Get-ADUser -Filter * | Sort-Object Name | Format-Table Name, UserPrincipalName to verify changes" -ForegroundColor White
        Write-Host "  2. Synchronize changes with Azure AD if applicable" -ForegroundColor White
        Write-Host "  3. Test email flow for both old and new domain addresses" -ForegroundColor White
    }
}