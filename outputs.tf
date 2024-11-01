output "app_service_public_domain" {
  value       = azurerm_app_service.app.default_site_hostname
  description = "Public domain for App Service"
}