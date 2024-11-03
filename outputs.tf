output "app_service_public_domain" {
  value       = azurerm_app_service.app.default_site_hostname
  description = "Public domain for App Service"
}
output "app_service_sku" {
  value       = azurerm_app_service_plan.app_plan.sku
  description = "Sku for App Service"
}
output "storage_account_id" {
  value       = azurerm_storage_account.storage_account.id
  description = "ID of the Storage Account"
}
output "storage_account_primary_connection_string" {
  value       = azurerm_storage_account.storage_account.primary_access_key
  description = "Primary connection string for the Storage Account"
  sensitive   = true
}
output "fileshare_name" {
  value       = azurerm_storage_share.file_share.url
  description = "Uri of the File Share"
}
output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "Login server URL for the ACR"
}
output "sql_database_sku" {
  description = "Sku for the Sql database"
  value       = azurerm_mssql_database.sql_db.sku_name
}
output "key_vault_url" {
  description = "Vault URI"
  value       = azurerm_key_vault.kv.vault_uri
}

