Function Show-AksInfo {
    <#
    .SYNOPSIS
    Retrieves and displays AKS cluster information, including VNet details.

    .DESCRIPTION
    Fetches all AKS clusters in a given Azure subscription and retrieves their 
    resource groups, associated virtual networks, and subnet details. This function 
    is designed for Azure CNI-based AKS clusters.

    .PARAMETER SubscriptionId
    (Optional) Specifies the Azure subscription ID to use when querying AKS clusters 
    and network details. If not provided, the function uses the currently active 
    Azure subscription.

    .EXAMPLE
    Show-AksInfo
    Retrieves AKS cluster information using the currently active Azure subscription.

    .EXAMPLE
    Show-AksInfo -SubscriptionId "e432466e-7fb8-4734-a361-8d42befe77d5"
    Retrieves AKS cluster information from the specified Azure subscription.

    .OUTPUTS
    Displays a formatted table containing:
    - ClusterName: Name of the AKS cluster.
    - ResourceGroup: The resource group where the AKS cluster is deployed.
    - VNetResourceGroup: The resource group where the associated VNet is located.
    - VNetName: The name of the virtual network used by the AKS cluster.
    - SubnetName: The name of the subnet associated with the AKS cluster.
    - SubnetRange: The subnet’s address range.

    .NOTES
    - This function requires Azure CLI (`az`).
    - The user must be authenticated with Azure CLI before running this function.
    - Works only with AKS clusters configured with Azure CNI (not Kubenet).
    - Uses the first available node pool's `vnetSubnetId` as the source for networking details.

    .LINK
    https://learn.microsoft.com/en-us/cli/azure/aks
    https://learn.microsoft.com/en-us/cli/azure/network/vnet
    #>

    [CmdletBinding()]
    param (
        [string]$SubscriptionId
    )

    # Ensure Az CLI is installed
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Host "Azure CLI (az) is not installed. Please install it first."
        exit 1
    }

    # Build AZ CLI subscription argument
    $subscriptionArg = @()
    if ($SubscriptionId) {
        $subscriptionArg = @("--subscription", $SubscriptionId)
    }

    # Get all AKS clusters in the specified or current subscription
    $aksClusters = az aks list @subscriptionArg --query "[].{name:name, resourceGroup:resourceGroup, agentPoolProfiles:agentPoolProfiles}" --output json | ConvertFrom-Json

    # Create an array to store results
    $results = @()

    foreach ($aks in $aksClusters) {
        # Ensure agentPoolProfiles exists and has at least one pool
        if ($aks.agentPoolProfiles -and $aks.agentPoolProfiles.Count -gt 0) {
            $subnetId = $aks.agentPoolProfiles[0].vnetSubnetId

            if ($subnetId) {
                $vnetDetails = Get-VNetSubnetDetails -subnetId $subnetId

                # Ensure VNet details exist before proceeding
                if ($vnetDetails) {
                    # Get subnet details (address prefix) with the correct subscription parameter
                    $subnetDetails = az network vnet subnet show --resource-group $vnetDetails.VNetResourceGroup --vnet-name $vnetDetails.VNetName --name $vnetDetails.SubnetName @subscriptionArg --query "{addressPrefix:addressPrefix}" --output json | ConvertFrom-Json

                    # Add to results
                    $results += [PSCustomObject]@{
                        ClusterName       = $aks.name
                        ResourceGroup     = $aks.resourceGroup
                        VNetResourceGroup = $vnetDetails.VNetResourceGroup
                        VNetName          = $vnetDetails.VNetName
                        SubnetName        = $vnetDetails.SubnetName
                        SubnetRange       = $subnetDetails.addressPrefix
                    }
                }
            }
        }
    }

    # Display the table
    if ($results.Count -gt 0) {
        $results | Format-Table -AutoSize
    } else {
        Write-Host "No AKS clusters with VNet information found." -ForegroundColor Red
    }
}

# Function to extract VNet and Subnet details from a subnet ID
function Get-VNetSubnetDetails {
    param (
        [string]$subnetId
    )
    if ($subnetId -match "/subscriptions/[^/]+/resourceGroups/([^/]+)/providers/Microsoft.Network/virtualNetworks/([^/]+)/subnets/([^/]+)") {
        return @{
            VNetResourceGroup = $matches[1]
            VNetName          = $matches[2]
            SubnetName        = $matches[3]
        }
    }
    return $null
}