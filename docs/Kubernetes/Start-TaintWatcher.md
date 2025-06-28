---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Start-TaintWatcher

## SYNOPSIS
Continuously monitors and logs Kubernetes node taints to a file.

## SYNTAX

```
Start-TaintWatcher
```

## DESCRIPTION
The Start-TaintWatcher function continuously monitors Kubernetes nodes for taints and logs their status to a file.
It runs in an infinite loop, checking for taints every 2 seconds and recording the results to 'taint_watch.log'.
This is useful for troubleshooting node scheduling issues or monitoring cluster state changes over time.

Requires kubectl to be installed and configured to access the target cluster.

## EXAMPLES

### EXAMPLE 1
```
Start-TaintWatcher
```

Starts monitoring node taints and logs them to 'taint_watch.log' in the current directory.
Use Ctrl+C to stop the monitoring process.

### EXAMPLE 2
```
Start-Job -ScriptBlock { Start-TaintWatcher }
```

Runs the taint monitoring as a background job.

## PARAMETERS

## INPUTS

## OUTPUTS

## NOTES
Author: Michiel VH
Requirements: Kubernetes CLI (kubectl) must be installed and configured
File: taint_watch.log will be created in the current directory

## RELATED LINKS
