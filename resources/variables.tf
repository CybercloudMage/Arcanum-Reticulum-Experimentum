variable "ENVIRONMENT" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.ENVIRONMENT)
    error_message = "ENVIRONMENT must be one of: dev, test, prod."
  }
}

variable "AZURE_ROOT_RESOURCE_GROUP_NAME" {
  description = "The name of the Azure Resource Group where the root resources will be deployed."
  type        = string
}

variable "AZURE_ROOT_VIRTUAL_NETWORK_NAME" {
  description = "The name of the Azure Virtual Network to be used for the resources."
  type        = string
}

variable "AZURE_KEY_VAULT_NAME" {
  description = "The name of the Azure Key Vault to be used for the resources."
  type        = string
}