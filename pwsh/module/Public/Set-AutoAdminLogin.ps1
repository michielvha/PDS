Function Set-AutoAdminLogin {
    <#
    .SYNOPSIS
        Sets the system to automatically log in with a specified user account. This is especially useful in development environments where auto-login is needed for testing purposes.

    .DESCRIPTION
        The `Set-AutoAdminLogin` function configures the Windows system to automatically log in to a specified user account upon boot.
        It achieves this by modifying the necessary registry keys (`DefaultUserName`, `DefaultPassword`, and `AutoAdminLogon`) to enable the auto-login feature.
        This function is particularly useful for development builds where manual login is unnecessary and auto-login streamlines the process.

        **Note:** The password is currently stored in plain text, so make sure to use this function in secure environments or find an encryption mechanism
        for storing the password securely.

    .PARAMETER Username
        The username of the account that should be automatically logged in on system startup.

    .PARAMETER Password
        The password of the user account. **Important**: Currently, the password is stored in plain text in the registry.
        Consider using a method to securely encrypt the password.

    .EXAMPLE
        Set-AutoAdminLogin -Username "devUser" -Password "devPass123"

        This example configures the system to automatically log in to the account `devUser` with the password `devPass123`.
        The system will bypass the login screen and log in to this account after rebooting.

    .NOTES
        Author: MKTHEPLUGG
        This function modifies registry keys to configure auto-login, so it must be run with elevated (Administrator) privileges.

    .LINK
        https://support.microsoft.com/en-us/help/324737/how-to-turn-on-automatic-logon-in-windows
        Microsoft support article on configuring auto-logon in Windows.

    #>

    param (
        [Alias("u")]
        [string]$Username,

        [Alias("p")]
        [SecureString]$Password
    )

#    # Define the auto-login user and password
#    $Username = "YourUsername"    # Replace with your username
#    # TDO: Implement password encryption to securely store the password in the registry
#    $Password = "YourPassword"    # Replace with your password

    # Registry path for auto-login settings
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    # Set the DefaultUserName and password (creates the key if it doesn't exist)
    if($Username){
        try {
            write-output "setting ${Username} as DefaultUserName"
            Set-ItemProperty -Path $registryPath -Name "DefaultUserName" -Value $Username
        } catch {
            write-output "An error occured while trying to set the ``DefaultUserName``: $_"
        }
    }
    if($Password){
        try {
            write-output "setting DefaultPassword"
            Set-ItemProperty -Path $registryPath -Name "DefaultPassword" -Value $Password
        } catch {
            write-output "An error occured while trying to set the ``DefaultPassword``: $_"
        }
    }

    # Enable AutoAdminLogon by setting it to "1"
    Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "1"

    # Verify the changes were applied
    Get-ItemProperty -Path $registryPath | Select-Object DefaultUserName, DefaultPassword, AutoAdminLogon
}
