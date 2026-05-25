// ============================================
// Azure Key Vault Secret App
// ----------------------------------------------
// Provisions a Key Vault (RBAC), three secrets,
// an App Service plan, a Web App with a system-
// assigned managed identity, and the role
// assignment that lets the Web App read secrets
// from the Key Vault.
// ============================================

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Unique suffix appended to resource names. Defaults to a hash of the resource group ID.')
param resourceSuffix string = uniqueString(resourceGroup().id)

@description('Key Vault name. Must be globally unique, 3-24 chars, alphanumeric.')
param keyVaultName string = 'kv${resourceSuffix}'

@description('Web App name. Must be globally unique.')
param webAppName string = 'kvapp${resourceSuffix}'

@description('App Service plan SKU.')
param appServicePlanSku string = 'B1'

@secure()
@description('DatabaseConnection secret value.')
param databaseConnection string

@secure()
@description('ApiKey secret value.')
param apiKey string

@secure()
@description('AppSecret secret value.')
param appSecret string

// Built-in role definition ID for "Key Vault Secrets User".
// Lets the principal read secret values from Key Vault.
var keyVaultSecretsUserRoleId = '4633458b-17de-41a5-8b4b-ea4ce8a2a48c'

// ============================================
// KEY VAULT
// ============================================
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
  }
}

// ============================================
// SECRETS
// ============================================
resource secretDatabaseConnection 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'DatabaseConnection'
  properties: {
    value: databaseConnection
  }
}

resource secretApiKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ApiKey'
  properties: {
    value: apiKey
  }
}

resource secretAppSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AppSecret'
  properties: {
    value: appSecret
  }
}

// ============================================
// APP SERVICE PLAN
// ============================================
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${webAppName}-plan'
  location: location
  sku: {
    name: appServicePlanSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ============================================
// WEB APP (with system-assigned managed identity)
// ============================================
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|9.0'
      appSettings: [
        {
          name: 'KeyVaultName'
          value: keyVault.name
        }
      ]
    }
  }
}

// ============================================
// ROLE ASSIGNMENT
// Grants the Web App's managed identity the
// "Key Vault Secrets User" role on the vault.
// ============================================
resource webAppKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webApp.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================
// OUTPUTS
// ============================================
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output keyVaultName string = keyVault.name
