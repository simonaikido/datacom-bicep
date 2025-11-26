param accountName string
param location string = resourceGroup().location
param logAnalyticsWorkspaceResourceId string = ''

// Reference the existing Cosmos DB account
resource existingCosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: accountName
}

// Create Log Analytics Workspace if not provided
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (empty(logAnalyticsWorkspaceResourceId)) {
  name: '${accountName}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: {
    Purpose: 'Cosmos DB Monitoring'
  }
}

// Diagnostic settings for Cosmos DB account
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${accountName}-diagnostics'
  scope: existingCosmosAccount
  properties: {
    workspaceId: empty(logAnalyticsWorkspaceResourceId) ? logAnalyticsWorkspace.id : logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'PartitionKeyStatistics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'PartitionKeyRUConsumption'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'Requests'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

output logAnalyticsWorkspaceId string = empty(logAnalyticsWorkspaceResourceId)
  ? logAnalyticsWorkspace.id
  : logAnalyticsWorkspaceResourceId
