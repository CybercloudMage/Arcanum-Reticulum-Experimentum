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
  default     = "rg-cybercloudmaage-infra-${var.ENVIRONMENT}"
}

# Variable for the location of the resource group
variable "RESOURCE_GROUP_LOCATION" {
  description = "The location of the resource group to create."
  type        = string
  default     = "westus2"
  validation {
    condition     = can(regex("^us", lower(var.location))) || can(regex("us[0-9]*$", lower(var.location)))
    error_message = "location must be a valid US Azure region."
  }
}