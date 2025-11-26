using '../main.bicep'

// General parameters
param environment = 'test'
param location = 'Australia East'
param databaseThroughput = null
param containerThroughput = null
param enablePublicAccess = true
param allowedIpRanges = []

// Key Vault parameters
param principalIds = [
  'sdjhflksjdhfkljsdhflkjhsdkljfhsdkljf' // Example User Object ID
  'sdkjfhslkjdfhlkjsdhflkjshdflkjhsdsdk' // Example Service Principal Object ID
]
param principalTypes = [
  'User'
  'ServicePrincipal'
]

// Tags
param tags = {}
