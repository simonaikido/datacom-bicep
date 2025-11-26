param keyVaultName string
param location string
param tenantId string = tenant().tenantId
param enabledForDeployment bool = false
param enabledForTemplateDeployment bool = false
param enabledForDiskEncryption bool = false
param enableRbacAuthorization bool = true
param enablePurgeProtection bool = true
param enableSoftDelete bool = true
param softDeleteRetentionInDays int = 90
param publicNetworkAccess string = 'Enabled'
param allowedIpRanges array = []
param tags object = {}

// SKU configuration
param skuName string = 'standard'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enabledForDeployment: enabledForDeployment
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enableRbacAuthorization: enableRbacAuthorization
    enablePurgeProtection: enablePurgeProtection
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: empty(allowedIpRanges) ? 'Allow' : 'Deny'
      ipRules: [
        for ipRange in allowedIpRanges: {
          value: ipRange
        }
      ]
    }
  }
}

// Outputs
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultResourceId string = keyVault.id
