
# Data Source for Azure Client Configuration
data "azurerm_client_config" "current" {}

data "http" "my_ip" {
  url = "https://ipinfo.io/ip"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-bestrong"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet-app" {
  name                 = "subnet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.KeyVault", "Microsoft.Sql", "Microsoft.Storage"]
  delegation {
    name = "webAppDelegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "subnet-sql" {
  name                 = "subnet-sql"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.KeyVault"]

}

resource "azurerm_subnet" "subnet-kv" {
  name                 = "subnet-kv"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.KeyVault"]
}

resource "azurerm_subnet" "storage_subnet" {
  name                 = "storage-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

# App Service Plan
resource "azurerm_app_service_plan" "app_plan" {
  name                = "asp-bestrong01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    tier = "Basic"
    size = "B1"
  }
}

# App Service
resource "azurerm_app_service" "app" {
  name                = "app-bestrong01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.app_plan.id

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"           = azurerm_application_insights.app_insights.instrumentation_key
    "AzureWebJobsStorage"                      = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.storage_account.name};AccountKey=${azurerm_storage_account.storage_account.primary_access_key};EndpointSuffix=core.windows.net"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.storage_account.name};AccountKey=${azurerm_storage_account.storage_account.primary_access_key};EndpointSuffix=core.windows.net"
    "WEBSITE_CONTENTSHARE"                     = azurerm_storage_share.file_share.name
    "WEBSITE_VNET_ROUTE_ALL"                   = true
    WEBSITE_CONTENTOVERVNET                    = 1
  }
}

# VNet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "app_vnet_integration" {
  app_service_id = azurerm_app_service.app.id
  subnet_id      = azurerm_subnet.subnet-app.id
}

# Application Insights
resource "azurerm_application_insights" "app_insights" {
  name                = "ai-bestrong"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

# Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = "acrbestrong02"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westeurope"
  sku                 = "Basic"
  admin_enabled       = true
}

# Role Assignment for App Service Identity to access ACR
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_app_service.app.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                = "kv-bestrong"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"

  tenant_id = data.azurerm_client_config.current.tenant_id



  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"

    # Allow
    virtual_network_subnet_ids = [
      azurerm_subnet.subnet-app.id,
      azurerm_subnet.subnet-sql.id,
      azurerm_subnet.subnet-kv.id
    ]

    ip_rules = [trimspace(data.http.my_ip.response_body)]

  }
}

# Endpoint for Key Vault
resource "azurerm_private_endpoint" "kv_private_endpoint" {
  name                = "pe-kv-beststrong"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet-kv.id

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# Key Vault Access Policy for Azure user
resource "azurerm_key_vault_access_policy" "user_access_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id # Поточний користувач або сервісний обліковий запис

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
}

# Key Vault Access Policy for App Service Identity
resource "azurerm_key_vault_access_policy" "app_access_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_app_service.app.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sqlAdminPassword"
  value        = var.password_for_sql
  key_vault_id = azurerm_key_vault.kv.id

  depends_on   = [ azurerm_key_vault_access_policy.user_access_policy ]
}

resource "azurerm_key_vault_secret" "sql_admin_loggin" {
  name         = "sqlAdminLoggin"
  value        = var.login_for_sql
  key_vault_id = azurerm_key_vault.kv.id

  depends_on   = [ azurerm_key_vault_access_policy.user_access_policy ]
}

# SQL Server
resource "azurerm_mssql_server" "sql_server" {
  name                         = "sql-server-bestrong"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.login_for_sql
  administrator_login_password = var.password_for_sql

  depends_on = [ azurerm_key_vault.kv ]
}

# SQL Database
resource "azurerm_mssql_database" "sql_db" {
  name                 = "db-bestrong"
  server_id            = azurerm_mssql_server.sql_server.id
  sku_name            = "GP_S_Gen5_2"
  max_size_gb          = 32
  zone_redundant       = true
  storage_account_type = "Zone"
  read_replica_count   = 1
  min_capacity         = 2
  auto_pause_delay_in_minutes = 60

}

# Endpoint for database
resource "azurerm_private_endpoint" "sql_private_endpoint" {
  name                = "pe-sql-beststrong"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet-sql.id

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }
}

resource "azurerm_mssql_virtual_network_rule" "sql-rule" {
  name      = "sql-vnet-rule"
  server_id = azurerm_mssql_server.sql_server.id
  subnet_id = azurerm_subnet.subnet-app.id
}


# Storage account
resource "azurerm_storage_account" "storage_account" {
  name                     = "beststrongstorage02"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]

    virtual_network_subnet_ids = [
      azurerm_subnet.subnet-app.id
    ]

    ip_rules = [trimspace(data.http.my_ip.response_body)]
  }
}

# Privat endpoint for storage
resource "azurerm_private_endpoint" "storage_private_endpoint" {
  name                = "pe-storage-beststrong"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.storage_subnet.id

  private_service_connection {
    name                           = "psc-storage"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    subresource_names              = ["file"]
  }

}

resource "azurerm_storage_share" "file_share" {
  name                 = "fileshare-beststrong"
  storage_account_name = azurerm_storage_account.storage_account.name
  quota                = 50
}

