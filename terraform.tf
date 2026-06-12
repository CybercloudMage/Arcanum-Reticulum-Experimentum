terraform {
  required_version = ">= 1.10.0, < 2.0.0"

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
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Configure the Azure Resource Manager (azurerm) provider
provider "azurerm" {
  features {}
}

provider "azapi" {}