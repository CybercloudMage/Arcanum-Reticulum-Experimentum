# Defintiion of the resource group that all other resources will be created in
resource "azurerm_resource_group" "rg" {
  name     = var.RESOURCE_GROUP_NAME
  location = var.RESOURCE_GROUP_LOCATION
}