Function New-AdminLegacy {
    <#
    .SYNOPSIS
    Create a new local user account with administrative privileges using legacy commands.
    
    .DESCRIPTION
    
    .PARAMETER Username
    
    .PARAMETER Credential

    .EXAMPLE
    Create-Admin -Credential (Get-Credential)  -FullName "Example" -Description "Example admin account"

    .NOTES
    This function only work in PS 5.1 and below.
    
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
    
    # Check if the user already exists
    if (Get-LocalUser -Name $Credential.Username -ErrorAction SilentlyContinue) {
        Write-Host "User $($Credential.Username) already exists."
        return
    }

    # Set fallback values
    if (!$FullName) { $FullName = $Credential.Username }
    if (!$Description) { $Description = "Local user account for $($Credential.Username)" }

    try {
        # Create the user
        New-LocalUser -Name $Credential.Username -Password $Credential.Password -FullName $FullName -Description $Description -AccountNeverExpires
        Add-LocalGroupMember -Group "Administrators" -Member $Credential.Username
        Write-Host "User $($Credential.Username) created and added to the Administrators group successfully."
    } catch {
        Write-Error "Failed to create user $($Credential.Username) : $($_.Exception.Message)"
    }
}