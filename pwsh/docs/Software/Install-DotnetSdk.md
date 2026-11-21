---
external help file: PDS-help.xml
Module Name: PDS
online version: https://learn.microsoft.com/en-us/dotnet/core/install/windows
schema: 2.0.0
---

# Install-DotnetSdk

## SYNOPSIS
Installs the latest .NET SDK of a release channel on Windows.

## SYNTAX

```
Install-DotnetSdk [[-Channel] <String>] [<CommonParameters>]
```

## DESCRIPTION
Installs the .NET SDK from the winget package `Microsoft.DotNet.SDK.<Channel>`, which tracks the newest SDK of that channel, or upgrades it when an older SDK of the channel is installed. The default channel is 10, the current long-term support release.

It installs winget with `Install-Winget` when it is missing, refreshes the session with `Update-Env`, and checks that `dotnet --list-sdks` reports an SDK of the channel. The function is safe to run again.

## EXAMPLES

### EXAMPLE 1
```
Install-DotnetSdk
```

Installs or upgrades the newest .NET 10 SDK.

### EXAMPLE 2
```
Install-DotnetSdk -Channel 11
```

Installs or upgrades the newest .NET 11 SDK.

## PARAMETERS

### -Channel
The .NET major version to install, as in `Microsoft.DotNet.SDK.10`. Defaults to 10.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## NOTES
- Requires administrator privileges and an internet connection.
- Open a new shell afterwards if other sessions need the updated PATH.

## RELATED LINKS

[.NET on Windows](https://learn.microsoft.com/en-us/dotnet/core/install/windows)
