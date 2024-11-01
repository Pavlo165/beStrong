terraform {
  backend "azurerm" {
    resource_group_name  = "beStrongTfState"
    storage_account_name = "backendaccount302"
    container_name       = "tfstate"
    key                  = "beststrong.tfstate"
  }
}