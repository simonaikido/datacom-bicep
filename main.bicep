targetScope = 'subscription'

param environment string
param location string = 'Australia East'
param resourceGroupName string = 'rg-secreports-${environment}'
param databaseThroughput int?
param containerThroughput int?
param principalIds array = [] // For role assignment to Key Vault
param principalTypes array = [] // Corresponding principal types (e.g., 'User', 'ServicePrincipal')
param tags object = {}

// Networking parameters
param enablePublicAccess bool = false
param allowedIpRanges array = []

// Key Vault parameters
param keyVaultName string = 'kv-secreports-${environment}-${take(uniqueString(subscription().subscriptionId), 5)}'
param enableKeyVaultRbac bool = true
param keyVaultPublicAccess string = 'Enabled'

// Cosmos DB parameters
param enableAnalyticalStorage bool = true // Enable if you need Synapse Link or advanced analytics
param cosmosdbAccountName string = 'secreports-nosql-${environment}-${uniqueString(subscription().subscriptionId)}'
param gremlinAccountName string = 'secreports-gremlin-${environment}-${uniqueString(subscription().subscriptionId)}'
param databaseNames array = ['secReportsDB-${environment}']
param databaseConfig array = [
  {
    databaseName: 'secReportsDB-${environment}'
    name: 'cvesContainer'
    partitionKey: '/cveId'
    compositeIndexes: [
      [
        {
          path: '/firstSeenTimestamp'
          order: 'ascending'
        }
        {
          path: '/updatedTimestamp'
          order: 'ascending'
        }
        {
          path: '/closedTimestamp'
          order: 'ascending'
        }
        {
          path: '/status'
          order: 'ascending'
        }
      ]
    ]
  }
  {
    databaseName: 'secReportsDB-${environment}'
    name: 'timeDataContainer'
    partitionKey: '/id'
    compositeIndexes: [
      [
        {
          path: '/timestamp'
          order: 'ascending'
        }
        {
          path: '/id'
          order: 'ascending'
        }
      ]
    ]
  }
]

param graphDatabaseName array = ['secReportsGDB-${environment}']
param graphDatabaseConfig array = [
  {
    databaseName: 'secReportsGDB-${environment}'
    name: 'graphContainer'
    partitionKey: '/tenantId_departmentId'
    compositeIndexes: []
  }
]

// Create the resource group
module resourceGroupModule './modules/resourceGroup.bicep' = {
  name: 'resourceGroupModule'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    tags: tags
  }
}

// Create the Key Vault
module keyVaultModule './modules/keyVault.bicep' = {
  name: 'keyVaultModule'
  scope: resourceGroup(resourceGroupName)
  params: {
    keyVaultName: keyVaultName
    location: location
    enableRbacAuthorization: enableKeyVaultRbac
    publicNetworkAccess: keyVaultPublicAccess
    allowedIpRanges: allowedIpRanges
    tags: tags
  }
  dependsOn: [
    resourceGroupModule
  ]
}

// Create the Cosmos DB account (SQL API)
module cosmosAccountModule './modules/cosmosDB/cosmosAccount.bicep' = {
  name: 'cosmosAccountModule'
  scope: resourceGroup(resourceGroupName)
  params: {
    accountName: cosmosdbAccountName
    location: location
    enablePublicAccess: enablePublicAccess
    enableAnalyticalStorage: enableAnalyticalStorage
    allowedIpRanges: allowedIpRanges
    keyVaultName: keyVaultModule.outputs.keyVaultName
    tags: tags
  }
}

// Create the Cosmos DB account (Gremlin API)
module cosmosGremlinAccountModule './modules/cosmosDB/cosmosGremlinAccount.bicep' = {
  name: 'cosmosGremlinAccountModule'
  scope: resourceGroup(resourceGroupName)
  params: {
    accountName: gremlinAccountName
    location: location
    enablePublicAccess: enablePublicAccess
    enableAnalyticalStorage: enableAnalyticalStorage
    allowedIpRanges: allowedIpRanges
    keyVaultName: keyVaultModule.outputs.keyVaultName
    tags: tags
  }
}

// Add role assignment module (only if principalId is provided)
module keyVaultRoleAssignmentModules './modules/keyVaultRoleAssignment.bicep' = [
  for (principalId, index) in principalIds: if (!empty(principalIds)) {
    name: 'keyVaultRoleAssignment-${index}'
    scope: resourceGroup(resourceGroupName)
    params: {
      keyVaultName: keyVaultModule.outputs.keyVaultName
      principalId: principalId
      principalType: principalTypes[index]
    }
    dependsOn: [
      cosmosAccountModule
    ]
  }
]

module cosmosSQLDatabaseModule './modules/cosmosDB/cosmosSQLDatabase.bicep' = [
  for databaseName in databaseNames: {
    name: 'cosmosDatabase-${replace(databaseName, '-', '')}'
    scope: resourceGroup(resourceGroupName)
    params: {
      accountName: cosmosdbAccountName
      databaseName: databaseName
      throughput: databaseThroughput
    }
    dependsOn: [
      cosmosAccountModule
    ]
  }
]

module cosmosSQLDatabaseContainerModules './modules/cosmosDB/cosmosSQLDatabaseContainer.bicep' = [
  for (item, index) in databaseConfig: {
    name: '${item.name}Module-${index}'
    scope: resourceGroup(resourceGroupName)
    params: {
      accountName: cosmosdbAccountName
      databaseName: item.databaseName
      containerName: item.name
      partitionKeyPath: item.partitionKey
      compositeIndexes: item.compositeIndexes
      throughput: containerThroughput
    }
    dependsOn: [
      cosmosSQLDatabaseModule
    ]
  }
]

// Create the Gremlin database using your module
module cosmosGremlinDatabaseModule './modules/cosmosDB/cosmosGremlinDatabase.bicep' = [
  for databaseName in graphDatabaseName: {
    name: 'cosmosGremlinDatabase-${replace(databaseName, '-', '')}'
    scope: resourceGroup(resourceGroupName)
    params: {
      accountName: gremlinAccountName
      databaseName: databaseName
      throughput: databaseThroughput
    }
    dependsOn: [
      cosmosGremlinAccountModule
    ]
  }
]

// Create the Gremlin containers (graphs) for the database using your module
module cosmosGremlinDatabaseGraphModules './modules/cosmosDB/cosmosGremlinDatabaseGraph.bicep' = [
  for (item, index) in graphDatabaseConfig: {
    name: 'cosmosGremlinDatabaseGraph-${replace(item.databaseName, '-', '')}-${index}'
    scope: resourceGroup(resourceGroupName)
    params: {
      accountName: gremlinAccountName
      databaseName: item.databaseName
      graphName: item.name
      partitionKeyPath: item.partitionKey
      throughput: containerThroughput
    }
    dependsOn: [
      cosmosGremlinDatabaseModule
    ]
  }
]

// Outputs for referencing from other deployments
output resourceGroupName string = resourceGroupModule.outputs.resourceGroupName
output keyVaultName string = keyVaultModule.outputs.keyVaultName
output keyVaultUri string = keyVaultModule.outputs.keyVaultUri
output keyVaultId string = keyVaultModule.outputs.keyVaultId
output keyVaultRoleAssignmentIds array = [
  for (principalId, index) in principalIds: !empty(principalIds) && keyVaultRoleAssignmentModules[index] != null
    ? keyVaultRoleAssignmentModules[index]!.outputs.roleAssignmentId
    : ''
]
output cosmosAccountName string = cosmosAccountModule.outputs.accountName
output cosmosAccountEndpoint string = cosmosAccountModule.outputs.endpoint
output cosmosKeySecretName string = cosmosAccountModule.outputs.secretName
output cosmosConnectionStringSecretName string = cosmosAccountModule.outputs.connectionStringSecretName

// Gremlin Cosmos DB outputs
output cosmosGremlinAccountName string = cosmosGremlinAccountModule.outputs.accountName
output cosmosGremlinAccountEndpoint string = cosmosGremlinAccountModule.outputs.endpoint
output cosmosGremlinKeySecretName string = cosmosGremlinAccountModule.outputs.secretName
output cosmosGremlinConnectionStringSecretName string = cosmosGremlinAccountModule.outputs.connectionStringSecretName

// Below is the content of the cosmosAccount.bicep module for reference
output deployedCosmosSQLDatabases array = [
  for (item, index) in databaseNames: !empty(databaseNames) && cosmosSQLDatabaseModule[index] != null
    ? {
        databaseName: item
        databaseId: cosmosSQLDatabaseModule[index].outputs.id
      }
    : {}
]
output deployedCosmosSQLDatabasesContainers array = [
  for (item, index) in databaseConfig: !empty(databaseConfig) && cosmosSQLDatabaseContainerModules[index] != null
    ? {
        databaseName: item.databaseName
        containerName: item.name
        containerId: cosmosSQLDatabaseContainerModules[index].outputs.id
        containerEndpoint: cosmosAccountModule.outputs.endpoint
        partitionKeyPath: item.partitionKey
        compositeIndexes: item.compositeIndexes
      }
    : {}
]
// Outputs for Gremlin databases
output deployedCosmosGremlinDatabases array = [
  for (item, index) in graphDatabaseName: !empty(graphDatabaseName) && cosmosGremlinDatabaseModule[index] != null
    ? {
        databaseName: item
        databaseId: cosmosGremlinDatabaseModule[index].outputs.id
      }
    : {}
]
output deployedCosmosGremlinDatabasesGraphs array = [
  for (item, index) in graphDatabaseConfig: !empty(graphDatabaseConfig) && cosmosGremlinDatabaseGraphModules[index] != null
    ? {
        databaseName: item.databaseName
        containerName: item.name
        containerId: cosmosGremlinDatabaseGraphModules[index].outputs.id
        containerEndpoint: cosmosGremlinAccountModule.outputs.endpoint
        partitionKeyPath: item.partitionKey
        compositeIndexes: item.compositeIndexes
      }
    : {}
]
