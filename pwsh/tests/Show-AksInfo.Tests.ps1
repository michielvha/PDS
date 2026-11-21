BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # az is an external executable the test machine may not have and must never run for
    # real; a module-scope stub lets Pester mock it.
    InModuleScope PDS { function script:az { } }
}

Describe 'Show-AksInfo' {
    BeforeEach {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'az' } { [pscustomobject]@{ Name = 'az' } }
        Mock Write-Progress -ModuleName PDS { }
        # One cluster on a custom VNet subnet and one kubenet cluster without a subnet.
        Mock az -ModuleName PDS -ParameterFilter { $args[0] -eq 'aks' -and $args[1] -eq 'list' } {
            $clusters = @(
                [pscustomobject]@{
                    name              = 'aks-prod'
                    resourceGroup     = 'rg-aks'
                    agentPoolProfiles = @([pscustomobject]@{
                            vnetSubnetId = '/subscriptions/0000/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/snet-aks'
                        })
                }
                [pscustomobject]@{
                    name              = 'aks-kubenet'
                    resourceGroup     = 'rg-aks'
                    agentPoolProfiles = @([pscustomobject]@{ vnetSubnetId = $null })
                }
            )
            ConvertTo-Json -InputObject $clusters -Depth 5
        }
        Mock az -ModuleName PDS -ParameterFilter { $args[0] -eq 'network' } { '{ "addressPrefix": "10.20.0.0/22" }' }
    }

    It 'shows the VNet, subnet and address range of each cluster on a custom subnet' {
        $table = Show-AksInfo | Out-String

        $table | Should -Match 'aks-prod\s+rg-aks\s+rg-net\s+vnet-hub\s+snet-aks\s+10\.20\.0\.0/22'
        $table | Should -Not -Match 'aks-kubenet'
        Should -Invoke az -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -like 'network vnet subnet show --resource-group rg-net --vnet-name vnet-hub --name snet-aks *'
        }
        Should -Invoke az -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $args -contains '--subscription' }
    }

    It 'passes the subscription to every az call' {
        Show-AksInfo -SubscriptionId 'sub-123' | Out-Null

        Should -Invoke az -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'aks' -and ($args -join ' ') -like '* --subscription sub-123 *'
        }
        Should -Invoke az -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'network' -and ($args -join ' ') -like '* --subscription sub-123 *'
        }
    }

    It 'reports when the subscription has no AKS clusters' {
        Mock az -ModuleName PDS -ParameterFilter { $args[0] -eq 'aks' -and $args[1] -eq 'list' } { '[]' }

        $messages = Show-AksInfo 6>&1 | ForEach-Object { "$_" }

        $messages | Should -Contain 'No AKS clusters found in the subscription.'
        Should -Invoke az -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $args[0] -eq 'network' }
    }

    It 'reports when no cluster uses a custom VNet subnet' {
        Mock az -ModuleName PDS -ParameterFilter { $args[0] -eq 'aks' -and $args[1] -eq 'list' } {
            ConvertTo-Json -Depth 5 -InputObject @([pscustomobject]@{
                    name              = 'aks-kubenet'
                    resourceGroup     = 'rg-aks'
                    agentPoolProfiles = @([pscustomobject]@{ vnetSubnetId = $null })
                })
        }

        $messages = Show-AksInfo 6>&1 | ForEach-Object { "$_" }

        $messages | Should -Contain 'No AKS clusters with VNet information found.'
        Should -Invoke az -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $args[0] -eq 'network' }
    }
}
