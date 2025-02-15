Function Show-AksInfo {
    <#
    .SYNOPSIS
    Retrieves and displays AKS cluster information, including VNet details.
    .DESCRIPTION
    Fetches all AKS clusters, their resource groups, virtual networks, and subnets.
    If the user is not logged in, it prompts for authentication.
    #>

    # Ensure Az CLI is installed
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Host "Azure CLI (az) is not installed. Please install it first."
        exit 1
    }

    # Get all AKS clusters in the subscription
    $aksClusters = az aks list --query "[].{name:name, resourceGroup:resourceGroup, agentPoolProfiles:agentPoolProfiles}" --output json | ConvertFrom-Json

    # Create an array to store results
    $results = @()

    foreach ($aks in $aksClusters) {
        $subnetId = $aks.agentPoolProfiles[0].vnetSubnetId  # Extract from the first agent pool

        $vnetDetails = Get-VNetSubnetDetails -subnetId $subnetId

        # Get subnet details (address prefix)
        $subnetDetails = az network vnet subnet show --resource-group $vnetDetails.VNetResourceGroup --vnet-name $vnetDetails.VNetName --name $vnetDetails.SubnetName --query "{addressPrefix:addressPrefix}" --output json | ConvertFrom-Json
        $subnetDetails
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

    # Display the table
    $results | Format-Table -AutoSize

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