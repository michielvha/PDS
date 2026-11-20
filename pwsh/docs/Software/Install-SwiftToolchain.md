---
external help file: PDS-help.xml
Module Name: PDS
online version: https://www.swift.org/install/windows/winget/
schema: 2.0.0
---

# Install-SwiftToolchain

## SYNOPSIS
Installs the latest Swift toolchain on Windows with Git and the Visual Studio Build Tools it needs.

## SYNTAX

```
Install-SwiftToolchain [[-Version] <String>] [[-WindowsSdkComponent] <String>] [-SkipDeveloperMode] [<CommonParameters>]
```

## DESCRIPTION
Prepares a Windows machine to build and test Swift packages, following swift.org's Windows instructions. It installs, where missing:

- Git, from the winget package `Git.Git`.
- Visual Studio 2022 Build Tools with the x64 MSVC tools and the Windows 11 SDK given by `-WindowsSdkComponent`. An existing Build Tools 2022 installation that lacks a component is modified to add it. swift.org documents Visual Studio 2022: the MSVC STL in Visual Studio 2026 requires Clang 22, newer than the Clang 21 that Swift 6.4 ships, so C and C++ dependencies stop compiling with error STL1000.
- The latest Swift toolchain from the winget package `Swift.Toolchain`, or `-Version` when given. An older installed toolchain is upgraded. winget also installs the package's declared dependencies: the Visual C++ redistributable and Python 3.10, which the toolchain's debugger needs.
- Developer Mode, which Swift Package Manager needs to create symbolic links, unless `-SkipDeveloperMode` is given.

It installs winget with `Install-Winget` when it is missing, refreshes the session with `Update-Env`, and checks `swift --version`. The function is safe to run again.

## EXAMPLES

### EXAMPLE 1
```
Install-SwiftToolchain
```

Installs Git, the Visual Studio 2022 Build Tools and the latest Swift where missing, and upgrades an older Swift.

### EXAMPLE 2
```
Install-SwiftToolchain -Version 6.4.2
```

Installs Swift 6.4.2, for example to match a project's continuous integration.

## PARAMETERS

### -Version
A Swift version to install, as winget lists it for `Swift.Toolchain`. Without it the latest version is installed.

```yaml
Type: String
Required: False
Default value: None (latest)
```

### -WindowsSdkComponent
The Visual Studio component ID of the Windows SDK to install with the Build Tools.

```yaml
Type: String
Required: False
Default value: Microsoft.VisualStudio.Component.Windows11SDK.26100
```

### -SkipDeveloperMode
Leaves Windows Developer Mode as it is.

```yaml
Type: SwitchParameter
Required: False
Default value: False
```

## NOTES
- Requires administrator privileges and an internet connection.
- The Build Tools download is several gigabytes, so the first run takes a while.
- Open a new shell afterwards if other sessions need the updated PATH.

## RELATED LINKS

[Install Swift on Windows with winget](https://www.swift.org/install/windows/winget/)

[Visual Studio Build Tools component IDs](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools)
