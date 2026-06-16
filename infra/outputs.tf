output "RESOURCE_GROUP_NAME" {
  value       = azurerm_resource_group.root.name
  description = "The root resource group name."
}

output "AZURE_VIRTUAL_NETWORK_NAME" {
  value       = module.vnet.name
  description = "The name of the Azure Virtual Network."
}

output "AZURE_VIRTUAL_NETWORK_SUBNET_IDS" {
  value = {
    for key, subnet in module.vnet.subnets :
    key => try(subnet.resource_id, subnet.id, subnet.resource.id)
  }
  description = "Subnet resource IDs keyed by logical subnet key."
}

output "KEY_VAULT_NAME" {
  value       = module.key_vault.name
  description = "The name of the Key Vault."
}

output "KEY_VAULT_URI" {
  value       = module.key_vault.uri
  description = "The URI of the Key Vault."
}

output "CONTAINER_REGISTRY_NAME" {
  value       = module.container_registry.name
  description = "The name of the Azure Container Registry."
}

output "CONTAINER_APP_NAME" {
  value       = module.container_app.name
  description = "The name of the Azure Container App."
}

output "FIREWALL_RESOURCE_ID" {
  value       = module.firewall.resource_id
  description = "The resource ID of the Azure Firewall."
}

output "FIREWALL_PUBLIC_IP" {
  value       = azurerm_public_ip.firewall.ip_address
  description = "The Azure Firewall public IP used for inbound gateway traffic."
}