function Set-AutoAdminLogin {
    <#
    .SYNOPSIS
        Signs a Windows account in automatically at startup, or turns that off again. Meant for test machines and kiosks.

    .DESCRIPTION
        `Set-AutoAdminLogin` turns on Windows automatic sign-in for one account. It first checks the password
        against the account, so a typo never leaves the machine stuck at the sign-in screen after a restart. Then it
        sets `DefaultUserName`, `DefaultDomainName` and `AutoAdminLogon` under the Winlogon key and stores the
        password as the LSA secret Winlogon reads (`DefaultPassword`), the way Sysinternals Autologon does. The
        password is never written to the registry in plain text, and a plain-text `DefaultPassword` value left by an
        earlier version or another tool is removed. On Windows 11 it also allows password sign-in when only Windows
        Hello sign-in is allowed, because automatic sign-in is ignored in that mode.

        `-Disable` turns automatic sign-in off and deletes the stored password.

        Run it elevated. The change takes effect at the next startup.

    .PARAMETER Username
        The account that signs in automatically.

    .PARAMETER Password
        The account's password. Leave it out for an account without a password.

    .PARAMETER Domain
        The account's domain. Defaults to this computer, for a local account.

    .PARAMETER Disable
        Turns automatic sign-in off and deletes the stored password.

    .EXAMPLE
        Set-AutoAdminLogin -Username 'tester' -Password (Read-Host -AsSecureString -Prompt 'Password')

        Signs the local account `tester` in automatically from the next startup on.

    .EXAMPLE
        Set-AutoAdminLogin -Disable

        Turns automatic sign-in off and removes the stored password.

    .NOTES
        Author: Michiel VH
        Requires administrator rights: it writes HKLM and the LSA secret store.

    .LINK
        https://learn.microsoft.com/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon
    #>

    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Enable')]
    param (
        [Parameter(ParameterSetName = 'Enable', Mandatory)]
        [Alias('u')]
        [string]$Username,

        [Parameter(ParameterSetName = 'Enable')]
        [Alias('p')]
        [SecureString]$Password,

        [Parameter(ParameterSetName = 'Enable')]
        [string]$Domain = $env:COMPUTERNAME,

        [Parameter(ParameterSetName = 'Disable', Mandatory)]
        [switch]$Disable
    )

    $winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $passwordLess = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'

    if ($Disable) {
        if ($PSCmdlet.ShouldProcess($winlogon, 'Turn off automatic sign-in and delete the stored password')) {
            Set-ItemProperty -Path $winlogon -Name 'AutoAdminLogon' -Value '0'
            Remove-ItemProperty -Path $winlogon -Name 'DefaultPassword' -ErrorAction SilentlyContinue
            Set-AutoLogonSecret -Value $null
            'Automatic sign-in is off and no password is stored.'
        }
        return
    }

    $credential = [pscredential]::new($Username, $(if ($Password) { $Password } else { [securestring]::new() }))
    if (-not (Test-AutoLogonCredential -Credential $credential -Domain $Domain)) {
        Write-Error "The password for $Domain\$Username was not accepted, so automatic sign-in was not changed."
        return
    }

    if ($PSCmdlet.ShouldProcess("$Domain\$Username", 'Sign in automatically at startup')) {
        Set-ItemProperty -Path $winlogon -Name 'DefaultUserName' -Value $Username
        Set-ItemProperty -Path $winlogon -Name 'DefaultDomainName' -Value $Domain
        Remove-ItemProperty -Path $winlogon -Name 'DefaultPassword' -ErrorAction SilentlyContinue
        Set-AutoLogonSecret -Value $credential.GetNetworkCredential().Password
        Set-ItemProperty -Path $winlogon -Name 'AutoAdminLogon' -Value '1'
        if (Test-Path -Path $passwordLess) {
            Set-ItemProperty -Path $passwordLess -Name 'DevicePasswordLessBuildVersion' -Value 0
        }
        "$Domain\$Username signs in automatically from the next startup."
    }
}

# Checks a password against a local or domain account without signing in.
function Test-AutoLogonCredential {
    param ([pscredential]$Credential, [string]$Domain)
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $type = if ($Domain -eq $env:COMPUTERNAME) {
        [System.DirectoryServices.AccountManagement.ContextType]::Machine
    }
    else {
        [System.DirectoryServices.AccountManagement.ContextType]::Domain
    }
    $context = [System.DirectoryServices.AccountManagement.PrincipalContext]::new($type, $Domain)
    try { $context.ValidateCredentials($Credential.UserName, $Credential.GetNetworkCredential().Password) }
    finally { $context.Dispose() }
}

# Stores the password as Winlogon's DefaultPassword LSA secret, or deletes the secret for $null.
function Set-AutoLogonSecret {
    [CmdletBinding(SupportsShouldProcess)]
    # Untyped: a [string] parameter would turn $null into an empty string, storing an empty password.
    param ($Value)
    if (-not ('PDS.LsaSecret' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace PDS {
    public static class LsaSecret {
        [StructLayout(LayoutKind.Sequential)]
        struct UnicodeString { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }

        [StructLayout(LayoutKind.Sequential)]
        struct ObjectAttributes {
            public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public uint Attributes;
            public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService;
        }

        [DllImport("advapi32.dll")]
        static extern uint LsaOpenPolicy(IntPtr systemName, ref ObjectAttributes attributes, uint access, out IntPtr policy);
        [DllImport("advapi32.dll")]
        static extern uint LsaStorePrivateData(IntPtr policy, ref UnicodeString keyName, IntPtr privateData);
        [DllImport("advapi32.dll")]
        static extern uint LsaNtStatusToWinError(uint status);
        [DllImport("advapi32.dll")]
        static extern uint LsaClose(IntPtr policy);

        const uint PolicyCreateSecret = 0x00000020;

        static UnicodeString Make(string text) {
            UnicodeString value = new UnicodeString();
            value.Buffer = Marshal.StringToHGlobalUni(text);
            value.Length = (ushort)(text.Length * 2);
            value.MaximumLength = (ushort)(value.Length + 2);
            return value;
        }

        // A null value deletes the secret.
        public static void Store(string key, string value) {
            ObjectAttributes attributes = new ObjectAttributes();
            attributes.Length = Marshal.SizeOf(typeof(ObjectAttributes));
            IntPtr policy;
            uint status = LsaOpenPolicy(IntPtr.Zero, ref attributes, PolicyCreateSecret, out policy);
            if (status != 0) throw new Win32Exception((int)LsaNtStatusToWinError(status));
            UnicodeString name = Make(key);
            UnicodeString secret = new UnicodeString();
            IntPtr data = IntPtr.Zero;
            try {
                if (value != null) {
                    secret = Make(value);
                    data = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(UnicodeString)));
                    Marshal.StructureToPtr(secret, data, false);
                }
                status = LsaStorePrivateData(policy, ref name, data);
                // Deleting a secret that does not exist is not an error.
                if (status != 0 && !(value == null && LsaNtStatusToWinError(status) == 2))
                    throw new Win32Exception((int)LsaNtStatusToWinError(status));
            }
            finally {
                if (secret.Buffer != IntPtr.Zero) Marshal.ZeroFreeGlobalAllocUnicode(secret.Buffer);
                if (data != IntPtr.Zero) Marshal.FreeHGlobal(data);
                Marshal.FreeHGlobal(name.Buffer);
                LsaClose(policy);
            }
        }
    }
}
'@
    }
    # PowerShell passes $null to a .NET string parameter as an empty string; NullString keeps it null.
    $secret = if ($null -eq $Value) { [NullString]::Value } else { [string]$Value }
    $action = if ($null -eq $Value) { 'Delete' } else { 'Store' }
    if ($PSCmdlet.ShouldProcess('LSA secret DefaultPassword', $action)) {
        [PDS.LsaSecret]::Store('DefaultPassword', $secret)
    }
}
