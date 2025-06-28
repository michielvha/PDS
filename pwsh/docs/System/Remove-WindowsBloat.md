---
external help file: PDS-help.xml
Module Name: PDS
online version: GitHub: https://github.com/michielvha/PDS

--- Disable services safely ---
schema: 2.0.0
---

# Remove-WindowsBloat

## SYNOPSIS
Disables non-essential and resource-heavy Windows services to improve system performance.

## SYNTAX

```
Remove-WindowsBloat
```

## DESCRIPTION
The Remove-WindowsBloat function disables a curated list of background Windows services known to consume CPU, RAM, and disk bandwidth unnecessarily on modern machines.
The script is safe for general use and avoids touching core system functionality or breaking essential features like networking or updates.

Most of the services targeted are:
    - Legacy or obsolete (e.g.
Fax, WAP Push)
    - Resource-intensive (e.g.
SysMain, Windows Search)
    - Xbox or demo-related (e.g.
RetailDemo, XblGameSave)
    - Rarely used by average users (e.g.
PhoneSvc, MessagingService)

The services are disabled using a helper function \`Disable-ServiceSafe\`, which ensures graceful shutdown and error handling.

## EXAMPLES

### EXAMPLE 1
```
Remove-WindowsBloat
```

Disables unnecessary Windows services to reduce background CPU and memory usage.

## PARAMETERS

## INPUTS

## OUTPUTS

## NOTES
Author: itmvha
Requires: PowerShell 5.1+ and Administrator privileges

## RELATED LINKS

[GitHub: https://github.com/michielvha/PDS

--- Disable services safely ---](GitHub: https://github.com/michielvha/PDS

--- Disable services safely ---)

[GitHub: https://github.com/michielvha/PDS

--- Disable services safely ---]()

