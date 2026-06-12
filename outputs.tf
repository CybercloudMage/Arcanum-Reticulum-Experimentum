output "resource_group_name" {
  description = "Root resource group name for the lab environment"
  value       = azurerm_resource_group.root_rg.name
}

output "virtual_network_id" {
  description = "Virtual network resource ID"
  value       = module.lab_vnet.resource_id
}

output "bastion_dns_name" {
  description = "Azure Bastion DNS name"
  value       = module.bastion.dns_name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.uri
}

output "windows_jumpbox_private_ip" {
  description = "Windows jump box private IP"
  value       = module.windows_jumpbox.virtual_machine_azurerm.private_ip_address
}

output "linux_jumpbox_private_ip" {
  description = "Linux jump box private IP"
  value       = module.linux_jumpbox.virtual_machine_azurerm.private_ip_address
}

output "windows_admin_username" {
  description = "Windows jump box local admin username"
  value       = "labadmin"
}

output "linux_admin_username" {
  description = "Linux jump box local admin username"
  value       = "labadmin"
}

output "windows_admin_password" {
  description = "Windows jump box local admin password"
  value       = random_password.windows_admin.result
  sensitive   = true
}

output "linux_admin_password" {
  description = "Linux jump box local admin password"
  value       = random_password.linux_admin.result
  sensitive   = true
}
