# Variable for the environment to deploy to (e.g. dev, test, prod)
variable "ENVIRONMENT" {
  description = "The environment to deploy to (e.g. dev, test, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.ENVIRONMENT)
    error_message = "ENVIRONMENT must be one of: dev, test, prod."
  }
}

# Variable for the name of the resource group if that is to be defined.
variable "RESOURCE_GROUP_NAME" {
  description = "The name of the resource group to create. If not provided, a default name will be generated."
  type        = string
  default     = "rg-arcanum-reticulum-lab"
}

# Variable for the location of the resource group
variable "RESOURCE_GROUP_LOCATION" {
  description = "The location of the resource group to create."
  type        = string
  default     = "eastus2"
  validation {
    condition     = can(regex("^us", lower(var.RESOURCE_GROUP_LOCATION))) || can(regex("us[0-9]*$", lower(var.RESOURCE_GROUP_LOCATION)))
    error_message = "location must be a valid US Azure region."
  }
}

variable "ADMIN_USER_ID" {
  description = "The object ID of the user to be added as an admin to the Key Vault. This should be the user running Terraform."
  type        = string
}

variable "ENABLE_ADMIN_ROLE_ASSIGNMENTS" {
  description = "Controls whether Terraform should create Owner and Key Vault Administrator role assignments for ADMIN_USER_ID."
  type        = bool
  default     = false
}

variable "ADMIN_USER_IPV4_ADDRESS" {
  description = "The IPv4 address of the user to be added to the Key Vault firewall rules. This should be the public IP address of the user running Terraform."
  type        = string
  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.ADMIN_USER_IPV4_ADDRESS))
    error_message = "ADMIN_USER_IPV4_ADDRESS must be a valid IPv4 address."
  }
}