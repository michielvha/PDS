BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    if (-not (Get-Command -Name Get-WmiObject -ErrorAction SilentlyContinue)) {
        InModuleScope PDS {
            function script:Get-WmiObject {
                [CmdletBinding()]
                param ([string]$Class, [string]$Namespace, [string[]]$ComputerName, [pscredential]$Credential)
                $null = $Class, $Namespace, $ComputerName, $Credential
            }
        }
    }

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

    function Get-FakeRegistryProvider {
        param ($Data)
        $provider = [pscustomobject]@{ Data = $Data }
        $provider | Add-Member -MemberType ScriptMethod -Name GetBinaryValue -Value {
            [pscustomobject]@{ uValue = $this.Data }
        }
        $provider
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
        $provider = Get-FakeRegistryProvider -Data (ConvertTo-DigitalProductId -Key $script:testKey)
        $os = $script:osInfo
        Mock Get-WmiObject -ModuleName PDS -ParameterFilter { $Class -eq 'StdRegProv' } -MockWith ({ $provider }.GetNewClosure())
        Mock Get-WmiObject -ModuleName PDS -ParameterFilter { $Class -eq 'Win32_OperatingSystem' } -MockWith ({ $os }.GetNewClosure())
        Mock Get-CimInstance -ModuleName PDS -MockWith ({ $os }.GetNewClosure())
        Mock Write-Warning -ModuleName PDS
    }

    It 'decodes the product key of a remote computer' {
        $result = Get-WindowsKey -Targets 'srv01'

        $result.Computer | Should -Be 'srv01'
        $result.ProductKey | Should -Be $script:testKey
        $result.Caption | Should -Be 'Microsoft Windows 11 Pro'
        $result.BuildNumber | Should -Be '26100'
        $result.RegisteredTo | Should -Be 'tester'
        $result.ProductID | Should -Be '00330-80000-00000-AA000'
        Should -Invoke Get-WmiObject -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Class -eq 'StdRegProv' -and $Namespace -eq 'root\default' -and $ComputerName -eq 'srv01'
        }
    }

    It 'accepts computer names from the pipeline' {
        $result = 'srv01', 'srv02' | Get-WindowsKey

        $result.Computer | Should -Be @('srv01', 'srv02')
        $result.ProductKey | Should -Be @($script:testKey, $script:testKey)
    }

    It 'passes the credential to the remote registry query' {
        $secure = [System.Net.NetworkCredential]::new('', 'test-only').SecurePassword
        $credential = [pscredential]::new('contoso\admin', $secure)

        $null = Get-WindowsKey -Targets 'srv01' -Credential $credential

        Should -Invoke Get-WmiObject -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Class -eq 'StdRegProv' -and $Credential.UserName -eq 'contoso\admin'
        }
    }

    It 'warns and returns nothing when the registry value is missing' {
        $empty = Get-FakeRegistryProvider -Data $null
        Mock Get-WmiObject -ModuleName PDS -ParameterFilter { $Class -eq 'StdRegProv' } -MockWith ({ $empty }.GetNewClosure())

        $result = Get-WindowsKey -Targets 'srv01'

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -eq 'Failed to retrieve product key data from srv01'
        }
    }

    It 'warns and returns nothing when the computer cannot be reached' {
        Mock Get-WmiObject -ModuleName PDS -ParameterFilter { $Class -eq 'StdRegProv' } -MockWith { throw 'RPC server unavailable' }

        $result = Get-WindowsKey -Targets 'srv01'

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like 'Error connecting to srv01*RPC server unavailable*'
        }
    }
}
