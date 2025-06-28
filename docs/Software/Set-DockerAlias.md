---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Set-DockerAlias

## SYNOPSIS
Sets functions for common Docker commands in the PowerShell profile for persistence.

## SYNTAX

```
Set-DockerAlias
```

## DESCRIPTION
The \`Set-DockerAlias\` function creates functions for common Docker commands and writes them to the PowerShell profile to ensure they persist across sessions.
The function checks if they are already set and only sets them if they are not defined.
This is the same as adding aliasses in linux.

The functions created by this script are:
- \`dcu\` for \`docker compose up -d\`
- \`d\` for \`docker\`
- \`dcd\` for \`docker compose down\`

## EXAMPLES

### EXAMPLE 1
```
Set-DockerAlias
```

.author: itmvha

## PARAMETERS

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
