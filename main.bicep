param location string = 'westeurope'
param name string = 'a9k-uptimekuma'

param guidValue string = newGuid()
var mysqlAdminPassword = '${toUpper(uniqueString(resourceGroup().id))}-${guidValue}'

resource env 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: name
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: listkeys(law.id, '2020-08-01').primarySharedKey
      }
    }
  }
}

resource law 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: name
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource app 'Microsoft.App/containerApps@2022-03-01' = {
  name: name
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3001
        transport: 'Auto'
        allowInsecure: true
      }
    }
    template: {
      volumes: [
        {
          name: 'azure-files-volume'
          storageType: 'AzureFile'
          storageName: managedstorage.name
        }
      ]
      containers: [
        {
          image: 'ghcr.io/adamhancock/uptime-kuma/uptime-kuma-mysql:mysql'
          name: 'uptime-kuma'
          env: [
            {
              name: 'DB_TYPE'
              value: 'mysql'
            }
            {
              name: 'DB_HOST'
              value: mysqlServer.properties.fullyQualifiedDomainName
            }
            {
              name: 'DB_NAME'
              value: 'uptimekuma'
            }
            {
              name: 'DB_USER'
              value: 'uptimekuma'
            }
            {
              name: 'DB_PASS'
              value: mysqlAdminPassword
            }
            {
              name: 'DB_SSL'
              value: 'true'
            }
          ]
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }

          volumeMounts: [
            {
              mountPath: '/app/data'
              volumeName: 'azure-files-volume'
            } ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/'
                port: 3001
                scheme: 'HTTP'
              }
              periodSeconds: 10
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/'
                port: 3001
                scheme: 'HTTP'
              }
              periodSeconds: 10
            }
            {
              type: 'Startup'
              httpGet: {
                path: '/'
                port: 3001
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  identity: {
    type: 'None'
  }
}

resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2021-12-01-preview' = {
  name: '${name}-mysql'
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: 'uptimekuma'
    createMode: 'Default'
    administratorLoginPassword: mysqlAdminPassword

    storage: {
      storageSizeGB: 20
      iops: 360
      autoGrow: 'Enabled'
    }
    version: '5.7'
    availabilityZone: '1'
    replicationRole: 'None'
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
  location: location

}
resource symbolicname 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2021-12-01-preview' = {
  name: '${name}-mysql-allow-azure'
  parent: mysqlServer
  properties: {
    // allow azure services
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource uptimekumadb 'Microsoft.DBforMySQL/flexibleServers/databases@2021-05-01-preview' = {
  name: 'uptimekuma'
  parent: mysqlServer
  properties: {
    charset: 'utf8'
    collation: 'utf8_general_ci'
  }
}

var storageName = '${replace(name, '-', '')}storage' // remove hyphens from name
resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  name: storageName
  location: location
  resource service 'fileServices' = {
    name: 'default'

    resource share 'shares' = {
      name: 'uptime-kuma'
    }
  }
  tags: {
  }
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource managedstorage 'Microsoft.App/managedEnvironments/storages@2022-06-01-preview' = {
  name: storageName
  parent: env
  properties: {
    azureFile: {
      accessMode: 'readWrite'
      accountKey: listkeys(storage.id, '2021-09-01').keys[0].value
      accountName: storageName
      shareName: 'uptime-kuma'
    }
  }
}
