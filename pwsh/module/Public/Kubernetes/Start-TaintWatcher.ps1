function Start-TaintWatcher {
    <#
    .SYNOPSIS
        Continuously monitors and logs Kubernetes node taints to a file.

    .DESCRIPTION
        The Start-TaintWatcher function continuously monitors Kubernetes nodes for taints and logs their status to a file.
        It runs in an infinite loop, checking for taints every 2 seconds and recording the results to 'taint_watch.log'.
        This is useful for troubleshooting node scheduling issues or monitoring cluster state changes over time.
        
        Requires kubectl to be installed and configured to access the target cluster.

    .EXAMPLE
        Start-TaintWatcher
        
        Starts monitoring node taints and logs them to 'taint_watch.log' in the current directory.
        Use Ctrl+C to stop the monitoring process.
    
    .EXAMPLE
        Start-Job -ScriptBlock { Start-TaintWatcher }
        
        Runs the taint monitoring as a background job.

    .NOTES
        Author: Michiel VH
        Requirements: Kubernetes CLI (kubectl) must be installed and configured
        File: taint_watch.log will be created in the current directory
    #>

    param()

   $logFile = "taint_watch.log"
    while ($true) {
        Add-Content $logFile "`n===== $(Get-Date) ====="
        
        $nodes = kubectl get nodes -o json | ConvertFrom-Json
        foreach ($node in $nodes.items) {
            $nodeName = $node.metadata.name
            $taints = $node.spec.taints

            if ($taints) {
                Add-Content $logFile "[$nodeName] has taints:"
                $taints | ForEach-Object { "$($_.key)=$($_.value):$($_.effect)" } | Add-Content $logFile
            } else {
                Add-Content $logFile "[$nodeName] has no taints."
            }
        }

        Start-Sleep -Seconds 2
    }

}
