BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Encodes a product key into a DigitalProductId byte array, the inverse of the decoder under
    # test: the 25 key characters are base-24 digits stored little-endian in bytes 52 to 66.
    function ConvertTo-DigitalProductId {
        param ([string]$Key)
        $chars = 'BCDFGHJKMPQRTVWXY2346789'
        $number = [System.Numerics.BigInteger]::Zero
        foreach ($char in $Key.Replace('-', '').ToCharArray()) {
            $number = $number * 24 + $chars.IndexOf($char)
        }
        $bytes = [byte[]]::new(164)
        for ($i = 52; $i -le 66; $i++) {
            $bytes[$i] = [byte][int][System.Numerics.BigInteger]::Remainder($number, 256)
            $number = [System.Numerics.BigInteger]::Divide($number, 256)
        }
        Write-Output -InputObject $bytes -NoEnumerate
    }

    $script:testKey = 'BCDFG-HJKMP-QRTVW-XY234-6789B'
    $script:osInfo = [pscustomobject]@{
        Caption        = 'Microsoft Windows 11 Pro'
        Version        = '10.0.26100'
        CSDVersion     = $null
        OSArchitecture = '64-bit'
        BuildNumber    = '26100'
        RegisteredUser = 'tester'
        SerialNumber   = '00330-80000-00000-AA000'
        InstallDate    = $null
    }
}

Describe 'Get-WindowsKey' {
    BeforeEach {
        $data = ConvertTo-DigitalProductId -Key $script:testKey
        $os = $script:osInfo
        # The CimSession parameters are typed; removing the type lets the mocks take a stand-in session.
        Mock New-CimSession -ModuleName PDS -MockWith { [pscustomobject]@{ ComputerName = "$ComputerName" } }
        Mock Invoke-CimMethod -ModuleName PDS -RemoveParameterType CimSession -MockWith ({ [pscustomobject]@{ ReturnValue = 0; uValue = $data } }.GetNewClosure())
        Mock Get-CimInstance -ModuleName PDS -RemoveParameterType CimSession -MockWith ({ $os }.GetNewClosure())
        Mock Remove-CimSession -ModuleName PDS -RemoveParameterType CimSession
        Mock Write-Warning -ModuleName PDS
    }

    It 'decodes the product key of a remote computer over a CIM session' {
        $result = Get-WindowsKey -Targets 'srv01'

        $result.Computer | Should -Be 'srv01'
        $result.ProductKey | Should -Be $script:testKey
        $result.Caption | Should -Be 'Microsoft Windows 11 Pro'
        $result.BuildNumber | Should -Be '26100'
        $result.RegisteredTo | Should -Be 'tester'
        $result.ProductID | Should -Be '00330-80000-00000-AA000'
        Should -Invoke New-CimSession -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'srv01' }
        Should -Invoke Invoke-CimMethod -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $CimSession.ComputerName -eq 'srv01' -and
            $Namespace -eq 'root\default' -and
            $ClassName -eq 'StdRegProv' -and
            $MethodName -eq 'GetBinaryValue' -and
            $Arguments.hDefKey -eq [uint32]2147483650 -and
            $Arguments.sSubKeyName -eq 'Software\Microsoft\Windows NT\CurrentVersion' -and
            $Arguments.sValueName -eq 'DigitalProductId'
        }
        Should -Invoke Get-CimInstance -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $ClassName -eq 'Win32_OperatingSystem' -and $CimSession.ComputerName -eq 'srv01'
        }
        Should -Invoke Remove-CimSession -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $CimSession.ComputerName -eq 'srv01' }
    }

    It 'accepts computer names from the pipeline' {
        $result = 'srv01', 'srv02' | Get-WindowsKey

        $result.Computer | Should -Be @('srv01', 'srv02')
        $result.ProductKey | Should -Be @($script:testKey, $script:testKey)
        Should -Invoke Remove-CimSession -ModuleName PDS -Times 2 -Exactly
    }

    It 'passes the credential to the CIM session' {
        $secure = [System.Net.NetworkCredential]::new('', 'test-only').SecurePassword
        $credential = [pscredential]::new('contoso\admin', $secure)

        $null = Get-WindowsKey -Targets 'srv01' -Credential $credential

        Should -Invoke New-CimSession -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $ComputerName -eq 'srv01' -and $Credential.UserName -eq 'contoso\admin'
        }
    }

    It 'warns and returns nothing when the registry value is missing' {
        Mock Invoke-CimMethod -ModuleName PDS -RemoveParameterType CimSession -MockWith {
            [pscustomobject]@{ ReturnValue = 1; uValue = $null }
        }

        $result = Get-WindowsKey -Targets 'srv01'

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -eq 'Failed to retrieve product key data from srv01'
        }
        Should -Invoke Remove-CimSession -ModuleName PDS -Times 1 -Exactly
    }

    It 'warns and returns nothing when the computer cannot be reached' {
        Mock New-CimSession -ModuleName PDS -MockWith { throw 'RPC server unavailable' }

        $result = Get-WindowsKey -Targets 'srv01'

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like 'Error connecting to srv01*RPC server unavailable*'
        }
        Should -Invoke Invoke-CimMethod -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Remove-CimSession -ModuleName PDS -Times 0 -Exactly
    }

    It 'returns InstallDate as the DateTime CIM provides' {
        $installed = [datetime]::new(2024, 3, 15, 10, 30, 0)
        $osWithDate = $script:osInfo.PSObject.Copy()
        $osWithDate.InstallDate = $installed
        Mock Get-CimInstance -ModuleName PDS -RemoveParameterType CimSession -MockWith ({ $osWithDate }.GetNewClosure())

        $result = Get-WindowsKey -Targets 'srv01'

        $result.InstallDate | Should -BeOfType [datetime]
        $result.InstallDate | Should -Be $installed
    }
}
