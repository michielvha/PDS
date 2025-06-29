Function New-Admin {
    <#
    .SYNOPSIS
        Create a new local user account with administrative privileges.
    
    .DESCRIPTION
    
    .PARAMETER Username
    
    .PARAMETER Credential

    .EXAMPLE
        # Create a credential object
        $Credential = Get-Credential

        # Call the function
        New-Admin -Credential $Credential -FullName "Test User" -Description "Test admin account"

    .NOTES
        This function is compatible with every version of powershell due to the use of System.DirectoryServices.AccountManagement .NET Core API for user creation.

        Author: Michiel VH
    .LINK
    #>

    param (
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential,

        [Parameter(Mandatory=$false)]
        [string]$FullName,

        [Parameter(Mandatory=$false)]
        [string]$Description
    )

    # Extract Username from Credential
    $Username = $Credential.UserName

    # Set defaults
    if (!$FullName) { $FullName = $Username }
    if (!$Description) { $Description = "Local user account for $Username" }

    try {
        # Load System.DirectoryServices.AccountManagement
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        # Create a new user context
        $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)

        # Check if the user already exists
        $existingUser = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($context, $Username)
        if ($existingUser) {
            Write-Host "User $Username already exists."
            return
        }

        # Create a new user
        $user = New-Object System.DirectoryServices.AccountManagement.UserPrincipal($context)
        $user.SamAccountName = $Username
        $user.SetPassword($Credential.GetNetworkCredential().Password)
        $user.DisplayName = $FullName
        $user.Description = $Description
        $user.Save()

        # Add user to Administrators group
        $group = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($context, "Administrators")
        $group.Members.Add($user)
        $group.Save()

        Write-Host "User $Username created and added to Administrators group."
    } catch {
        Write-Error "Failed to create user $Username : $($_.Exception.Message)"
    }
}
