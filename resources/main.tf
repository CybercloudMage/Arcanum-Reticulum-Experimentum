# Gathering the various data elements that will be needed for these resource definitions
data "azurerm_resource_group" "root" {
  name = var.AZURE_ROOT_RESOURCE_GROUP_NAME
}

data "azurerm_virtual_network" "root" {
  name                = var.AZURE_ROOT_VIRTUAL_NETWORK_NAME
  resource_group_name = data.azurerm_resource_group.root.name
}

data "azurerm_key_vault" "root" {
  name                = "kv-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  resource_group_name = data.azurerm_resource_group.root.name
}