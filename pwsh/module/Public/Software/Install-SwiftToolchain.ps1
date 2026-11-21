Function Install-SwiftToolchain {
    <#
    .SYNOPSIS
        Installs the latest Swift toolchain on Windows with Git and the Visual Studio Build Tools it needs.

    .DESCRIPTION
        Prepares a Windows machine to build and test Swift packages, following swift.org's Windows
        instructions:
        - Git, from winget package Git.Git, unless git is already on PATH
        - Visual Studio 2022 Build Tools with the x64 MSVC tools and the Windows 11 SDK given by
          -WindowsSdkComponent. An existing Build Tools 2022 installation that lacks a component is
          modified to add it. Visual Studio 2022 is what swift.org documents: the MSVC STL in
          Visual Studio 2026 requires Clang 22, newer than the Clang 21 that Swift 6.4 ships, and
          stops C and C++ dependencies from compiling (error STL1000)
        - The Swift toolchain from winget package Swift.Toolchain: the latest version, or -Version
          when given. An existing toolchain is upgraded to the latest. winget also installs the
          package's declared dependencies, the Visual C++ redistributable and Python 3.10, which
          the toolchain's debugger needs
        - Developer Mode, which Swift Package Manager needs to create symbolic links, unless
          -SkipDeveloperMode is given

        It reuses Install-Winget when winget is missing, refreshes the session's environment with
        Update-Env, and checks `swift --version`. The function is idempotent.

    .PARAMETER Version
        Optional. A Swift version to install, as winget lists it for Swift.Toolchain. Without it the
        latest version is installed, and an older installed toolchain is upgraded.

    .PARAMETER WindowsSdkComponent
        The Visual Studio component ID of the Windows SDK to install with the Build Tools.
        Defaults to Microsoft.VisualStudio.Component.Windows11SDK.26100.

    .PARAMETER SkipDeveloperMode
        Leaves Windows Developer Mode as it is.

    .EXAMPLE
        Install-SwiftToolchain

        Installs Git, the Visual Studio 2022 Build Tools and the latest Swift where missing, and
        upgrades an older Swift.

    .EXAMPLE
        Install-SwiftToolchain -Version 6.4.2

        Installs Swift 6.4.2, for example to match a project's continuous integration.

    .NOTES
        - Requires administrator privileges and an internet connection.
        - The Build Tools download is several gigabytes; the first run takes a while.
        - Open a new shell afterwards if other sessions need the updated PATH.

        Author: Michiel VH

    .LINK
        https://www.swift.org/install/windows/winget/
        https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d+\.\d+(\.\d+)?$')]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$WindowsSdkComponent = 'Microsoft.VisualStudio.Component.Windows11SDK.26100',

        [Parameter(Mandatory = $false)]
        [switch]$SkipDeveloperMode
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This function requires administrator privileges. Please run PowerShell as Administrator."
        return
    }

    $wingetArguments = @('--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    # 0 is success; 0x8A15002B (-1978335189) means there is no newer applicable version.
    $noApplicableUpdate = -1978335189
    $components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64', $WindowsSdkComponent)

    function Invoke-Winget {
        param([string]$Verb, [string]$Id, [string[]]$Extra = @())
        Write-Output "Running winget $Verb $Id..."
        & winget $Verb --id $Id @wingetArguments @Extra
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $noApplicableUpdate) {
            throw "winget $Verb $Id failed with exit code $LASTEXITCODE."
        }
    }

    try {
        if (-not (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
            Install-Winget
        }

        # 1. Git
        if (Get-Command -Name git -ErrorAction SilentlyContinue) {
            Write-Output "Git is already installed: $(git --version)"
        }
        else {
            Invoke-Winget -Verb install -Id 'Git.Git'
        }

        # 2. Visual Studio 2022 Build Tools with MSVC and the Windows SDK
        $installerDirectory = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer'
        $vswhere = Join-Path $installerDirectory 'vswhere.exe'
        $complete = $null
        $existing = $null
        if (Test-Path $vswhere) {
            $complete = & $vswhere -products * -version '[17.0,18.0)' -requires $components -latest -property installationPath
            $existing = & $vswhere -products Microsoft.VisualStudio.Product.BuildTools -version '[17.0,18.0)' -latest -property installationPath
        }
        if ($complete) {
            Write-Output "Visual Studio 2022 with MSVC and $WindowsSdkComponent is already installed: $complete"
        }
        elseif ($existing) {
            Write-Output "Adding MSVC and $WindowsSdkComponent to the Build Tools at $existing..."
            $addArguments = $components | ForEach-Object { '--add', $_ }
            $process = Start-Process -FilePath (Join-Path $installerDirectory 'setup.exe') -Wait -PassThru -ArgumentList (
                @('modify', '--installPath', "`"$existing`"", '--quiet', '--norestart', '--nocache') + $addArguments)
            # 3010 means success with a restart required.
            if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
                throw "Visual Studio installer modify failed with exit code $($process.ExitCode)."
            }
        }
        else {
            $override = "--wait --quiet --norestart --nocache " + (($components | ForEach-Object { "--add $_" }) -join ' ')
            Invoke-Winget -Verb install -Id 'Microsoft.VisualStudio.2022.BuildTools' -Extra @('--override', $override)
        }

        # 3. Swift
        Update-Env
        $installed = Get-Command -Name swift -ErrorAction SilentlyContinue
        if ($Version) {
            $current = if ($installed) { swift --version 2>&1 | Out-String } else { '' }
            if ($current -match "Swift version $([regex]::Escape($Version))\b") {
                Write-Output "Swift $Version is already installed."
            }
            else {
                Invoke-Winget -Verb install -Id 'Swift.Toolchain' -Extra @('--version', $Version, '--force')
            }
        }
        elseif ($installed) {
            Invoke-Winget -Verb upgrade -Id 'Swift.Toolchain'
        }
        else {
            Invoke-Winget -Verb install -Id 'Swift.Toolchain'
        }

        # 4. Developer Mode, for the symbolic links Swift Package Manager creates
        if (-not $SkipDeveloperMode) {
            $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
            if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
            Set-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
            Write-Output "Developer Mode is enabled."
        }

        # 5. Verify
        Update-Env
        $reported = (swift --version 2>&1 | Out-String)
        if ($reported -notmatch 'Swift version \d+\.\d+') {
            throw "swift --version did not report a Swift version. It reported: $reported"
        }
        if ($Version -and $reported -notmatch "Swift version $([regex]::Escape($Version))\b") {
            throw "swift --version does not report Swift $Version. It reported: $reported"
        }
        Write-Output "Swift toolchain ready: $($reported.Trim())"
    }
    catch {
        Write-Error "Install-SwiftToolchain failed: $_"
    }
}
