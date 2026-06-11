terraform {
  required_version = ">= 1.15.6"

  # Configure the Azure Resource Manager (azurerm) provider
  backend "azurerm" {
    use_azuread_auth = true
  }

  # Configure the required providers for the project
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.77"
    }
  }
}

# Configure the Azure Resource Manager (azurerm) provider
provider "azurerm" {}