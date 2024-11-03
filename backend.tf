terraform {
  backend "azurerm" {
    resource_group_name  = "beStrongTfState"
    storage_account_name = "backendaccount304"
    container_name       = "tfstatebestrong"
    key                  = "beststrong.tfstate"
  }
}