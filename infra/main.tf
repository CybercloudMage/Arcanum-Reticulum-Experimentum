resource "azurerm_resource_group" "root" {
  name     = "rg-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  location = var.AZURE_ROOT_REGION_NAME
}

data "azurerm_client_config" "current" {}

locals {
  # ACR names must be lowercase alphanumeric only; derive a compliant name from the requested prefix pattern.
  acr_name                   = lower(replace("CCMArcRetExpACR-${var.ENVIRONMENT}", "-", ""))
  container_image_repository = "apps/arcanum-reticulum"

  tags = {
    environment = var.ENVIRONMENT
    workload    = "arcanum-reticulum-experimentum"
    managedBy   = "terraform"
  }
}

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.18.0"

  name          = "vnet-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  location      = azurerm_resource_group.root.location
  parent_id     = azurerm_resource_group.root.id
  address_space = ["10.20.0.0/16"]
  peerings      = var.VNET_PEERINGS

  subnets = {
    bastion = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.20.0.0/27"]
    }
    azure_firewall = {
      name             = "AzureFirewallSubnet"
      address_prefixes = ["10.20.0.32/27"]
    }
    service_endpoints = {
      name             = "snet-service-endpoints"
      address_prefixes = ["10.20.0.64/26"]
      service_endpoints_with_location = [
        {
          service = "Microsoft.KeyVault"
        },
        {
          service = "Microsoft.ContainerRegistry"
        },
        {
          service = "Microsoft.Storage"
        }
      ]
    }
    private_endpoints = {
      name                              = "snet-private-endpoints"
      address_prefixes                  = ["10.20.0.128/26"]
      private_endpoint_network_policies = "Disabled"
    }
    admin_general = {
      name             = "snet-admin-general"
      address_prefixes = ["10.20.1.0/24"]
      delegations = [
        {
          name = "aca-delegation"
          service_delegation = {
            name = "Microsoft.App/environments"
          }
        }
      ]
    }
  }

  tags = local.tags
}

locals {
  subnet_ids = {
    for key, subnet in module.vnet.subnets :
    key => try(subnet.resource_id, subnet.id, subnet.resource.id)
  }
}

module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"

  name                = "kv-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  public_network_access_enabled = false
  purge_protection_enabled      = true

  network_acls = {
    bypass         = "None"
    default_action = "Deny"
  }

  private_endpoints = {
    keyvault = {
      subnet_resource_id            = local.subnet_ids.private_endpoints
      private_dns_zone_resource_ids = var.PRIVATE_DNS_ZONE_RESOURCE_IDS.key_vault
    }
  }

  tags = local.tags
}

module "container_registry" {
  source  = "Azure/avm-res-containerregistry-registry/azurerm"
  version = "0.5.1"

  name                = local.acr_name
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name

  sku                           = "Premium"
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = false

  network_rule_set = {
    default_action = "Deny"
    ip_rule        = []
  }

  private_endpoints = {
    acr = {
      subnet_resource_id            = local.subnet_ids.private_endpoints
      private_dns_zone_resource_ids = var.PRIVATE_DNS_ZONE_RESOURCE_IDS.container_registry
    }
  }

  tags = local.tags
}

module "container_app_environment" {
  source  = "Azure/avm-res-app-managedenvironment/azurerm"
  version = "0.5.0"

  name                = "cae-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name

  public_network_access = "Disabled"
  vnet_configuration = {
    internal                 = true
    infrastructure_subnet_id = local.subnet_ids.admin_general
  }

  tags = local.tags
}

module "container_app" {
  source  = "Azure/avm-res-app-containerapp/azurerm"
  version = "0.9.0"

  name                                  = "ca-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  resource_group_name                   = azurerm_resource_group.root.name
  container_app_environment_resource_id = try(module.container_app_environment.resource_id, module.container_app_environment.id)

  managed_identities = {
    system_assigned = true
  }

  ingress = {
    external_enabled = false
    target_port      = 8080
    additional_port_mappings = [
      {
        exposed_port = 8443
        external     = false
        target_port  = 8443
      }
    ]
    traffic_weight = [
      {
        latest_revision = true
        percentage      = 100
      }
    ]
  }

  registries = [
    {
      server = try(module.container_registry.resource.login_server, "${local.acr_name}.azurecr.io")
    }
  ]

  template = {
    min_replicas = 1
    max_replicas = 2
    containers = [
      {
        name   = "main"
        image  = "${local.acr_name}.azurecr.io/${local.container_image_repository}:${var.CONTAINER_IMAGE_TAG}"
        cpu    = 0.5
        memory = "1Gi"
      }
    ]
  }

  tags = local.tags
}

locals {
  # Internal ACA ingress is fronted by the managed environment private static IP.
  container_app_internal_ip = module.container_app_environment.static_ip_address

  storage_private_dns_zone_map = {
    for zone_id in var.PRIVATE_DNS_ZONE_RESOURCE_IDS.storage_account :
    zone_id => {
      name                = element(split("/", zone_id), 8)
      resource_group_name = element(split("/", zone_id), 4)
    }
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  for_each = local.storage_private_dns_zone_map

  name                  = "link-${replace(each.value.name, ".", "-")}-${var.ENVIRONMENT}"
  private_dns_zone_name = each.value.name
  resource_group_name   = each.value.resource_group_name
  virtual_network_id    = module.vnet.resource_id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_role_assignment" "container_app_acr_pull" {
  scope                = module.container_registry.resource_id
  role_definition_name = "AcrPull"
  principal_id         = module.container_app.identity.system_assigned.principal_id
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-fw-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_firewall_policy" "main" {
  name                = "afwp-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name
  sku                 = "Premium"

  threat_intelligence_mode = "Deny"
  tags                     = local.tags
}

module "firewall" {
  source  = "Azure/avm-res-network-azurefirewall/azurerm"
  version = "0.4.0"

  name                = "afw-cybercloudmage-arcretexp-${var.ENVIRONMENT}"
  location            = azurerm_resource_group.root.location
  resource_group_name = azurerm_resource_group.root.name

  firewall_sku_name  = "AZFW_VNet"
  firewall_sku_tier  = "Premium"
  firewall_policy_id = azurerm_firewall_policy.main.id

  ip_configurations = {
    main = {
      name                 = "ipconfig-main"
      subnet_id            = local.subnet_ids.azure_firewall
      public_ip_address_id = azurerm_public_ip.firewall.id
    }
  }

  tags = local.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "rcg-gateway"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 200

  application_rule_collection {
    name     = "arc-outbound-filter"
    priority = 200
    action   = "Allow"

    rule {
      name              = "allow-web-outbound"
      source_addresses  = ["10.20.0.0/16"]
      destination_fqdns = ["*"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  nat_rule_collection {
    name     = "arc-inbound-containerapp"
    priority = 300
    action   = "Dnat"

    rule {
      name                = "http-to-containerapp"
      protocols           = ["TCP"]
      source_addresses    = var.FIREWALL_ALLOWED_INGRESS_SOURCES
      destination_address = azurerm_public_ip.firewall.ip_address
      destination_ports   = ["80"]
      translated_address  = local.container_app_internal_ip
      translated_port     = "8080"
    }

    rule {
      name                = "https-to-containerapp"
      protocols           = ["TCP"]
      source_addresses    = var.FIREWALL_ALLOWED_INGRESS_SOURCES
      destination_address = azurerm_public_ip.firewall.ip_address
      destination_ports   = ["443"]
      translated_address  = local.container_app_internal_ip
      translated_port     = "8443"
    }
  }
}


