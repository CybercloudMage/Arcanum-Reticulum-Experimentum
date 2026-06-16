terraform {
  required_version = ">= 1.15.0"
  backend "azurerm" {
    use_azuread_auth = true
    use_oidc         = true
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.77.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.10.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}