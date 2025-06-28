---
external help file: PDS-help.xml
Module Name: PDS
online version: https://learn.microsoft.com/en-us/cli/azure/aks
https://learn.microsoft.com/en-us/cli/azure/network/vnet
schema: 2.0.0
---

# Show-AksInfo

## SYNOPSIS
Retrieves and displays AKS cluster information, including VNet details.

## SYNTAX

```
Show-AksInfo [[-SubscriptionId] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Fetches all AKS clusters in a given Azure subscription and retrieves their 
resource groups, associated virtual networks, and subnet details.
This function 
is designed for Azure CNI-based AKS clusters.

## EXAMPLES

### EXAMPLE 1
```
Show-AksInfo
Retrieves AKS cluster information using the currently active Azure subscription.
```

### EXAMPLE 2
```
Show-AksInfo -SubscriptionId "e432466e-7fb8-4734-a361-8d42befe77d5"
Retrieves AKS cluster information from the specified Azure subscription.
```

## PARAMETERS

### -SubscriptionId
(Optional) Specifies the Azure subscription ID to use when querying AKS clusters 
and network details.
If not provided, the function uses the currently active 
Azure subscription.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### Displays a formatted table containing:
### - ClusterName: Name of the AKS cluster.
### - ResourceGroup: The resource group where the AKS cluster is deployed.
### - VNetResourceGroup: The resource group where the associated VNet is located.
### - VNetName: The name of the virtual network used by the AKS cluster.
### - SubnetName: The name of the subnet associated with the AKS cluster.
### - SubnetRange: The subnet's address range.
## NOTES
- This function requires Azure CLI (\`az\`).
- The user must be authenticated with Azure CLI before running this function.
- Works only with AKS clusters configured with Azure CNI (not Kubenet).
- Uses the first available node pool's \`vnetSubnetId\` as the source for networking details.

## RELATED LINKS

[https://learn.microsoft.com/en-us/cli/azure/aks
https://learn.microsoft.com/en-us/cli/azure/network/vnet](https://learn.microsoft.com/en-us/cli/azure/aks
https://learn.microsoft.com/en-us/cli/azure/network/vnet)

[https://learn.microsoft.com/en-us/cli/azure/aks
https://learn.microsoft.com/en-us/cli/azure/network/vnet]()

