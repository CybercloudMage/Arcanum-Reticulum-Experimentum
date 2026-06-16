variable "ENVIRONMENT" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.ENVIRONMENT)
    error_message = "ENVIRONMENT must be one of: dev, test, prod."
  }
}

variable "AZURE_ROOT_REGION_NAME" {
  description = "The name of the Azure region where the root resources will be deployed."
  type        = string
}

variable "CONTAINER_IMAGE_TAG" {
  description = "Container image tag to deploy."
  type        = string
  default     = "latest"
}

variable "FIREWALL_ALLOWED_INGRESS_SOURCES" {
  description = "Source CIDR blocks allowed to hit firewall public IP inbound DNAT rules."
  type        = list(string)
  default     = ["*"]
}

variable "PRIVATE_DNS_ZONE_RESOURCE_IDS" {
  description = "Private DNS zone resource IDs hosted in another subscription, grouped by service."
  type = object({
    key_vault          = list(string)
    container_registry = list(string)
    storage_account    = list(string)
  })
}

variable "VNET_PEERINGS" {
  description = "VNet peering definitions passed directly to the AVM virtual network module."
  type        = map(any)
  default     = {}
}