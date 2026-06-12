# Defintiion of the resource group that all other resources will be created in
resource "azurerm_resource_group" "root_rg" {
  name     = var.RESOURCE_GROUP_NAME
  location = var.RESOURCE_GROUP_LOCATION
}

resource "azurerm_role_assignment" "admin_owner_root_rg" {
  scope                = azurerm_resource_group.root_rg.id
  role_definition_name = "Owner"
  principal_id         = var.ADMIN_USER_ID
  principal_type       = "User"

  depends_on = [azurerm_resource_group.root_rg]
}

data "azurerm_client_config" "current" {}

locals {
  name_suffix    = lower(var.ENVIRONMENT)
  key_vault_name = "kvarcanum${replace(lower(var.ENVIRONMENT), "-", "")}${substr(md5("${azurerm_resource_group.root_rg.id}-kv2"), 0, 6)}"

  tags = {
    environment = var.ENVIRONMENT
    workload    = "arcanum-reticulum-lab"
    managed_by  = "terraform"
  }
}

module "lab_vnet" {
  source = "Azure/avm-res-network-virtualnetwork/azurerm"

  name      = "vnet-arcanum-${local.name_suffix}"
  location  = azurerm_resource_group.root_rg.location
  parent_id = azurerm_resource_group.root_rg.id

  address_space = ["10.200.0.0/16"]

  # Use secure recursive resolvers for egress DNS lookups.
  dns_servers = {
    dns_servers = ["9.9.9.9", "1.1.1.1"]
  }

  subnets = {
    azurefirewall = {
      name                            = "AzureFirewallSubnet"
      address_prefixes                = ["10.200.0.0/26"]
      default_outbound_access_enabled = false
    }
    azurebastion = {
      name                            = "AzureBastionSubnet"
      address_prefixes                = ["10.200.0.64/28"]
      default_outbound_access_enabled = false
    }
    serviceendpoints = {
      name                            = "snet-service-endpoints"
      address_prefixes                = ["10.200.1.0/24"]
      default_outbound_access_enabled = false
      service_endpoints_with_location = [
        {
          service   = "Microsoft.KeyVault"
          locations = ["*"]
        },
        {
          service   = "Microsoft.Storage"
          locations = ["*"]
        }
      ]
    }
    privateendpoints = {
      name                              = "snet-private-endpoints"
      address_prefixes                  = ["10.200.2.0/24"]
      default_outbound_access_enabled   = false
      private_endpoint_network_policies = "Disabled"
    }
    generalaccess = {
      name                            = "snet-general-access"
      address_prefixes                = ["10.200.3.0/24"]
      default_outbound_access_enabled = false
    }
  }

  enable_telemetry = false
  tags             = local.tags
}

module "firewall_public_ip" {
  source = "Azure/avm-res-network-publicipaddress/azurerm"

  name                = "pip-fw-arcanum-${local.name_suffix}"
  location            = azurerm_resource_group.root_rg.location
  resource_group_name = azurerm_resource_group.root_rg.name

  sku               = "Standard"
  allocation_method = "Static"
  ip_version        = "IPv4"

  enable_telemetry = false
  tags             = local.tags
}

module "azure_firewall" {
  source = "Azure/avm-res-network-azurefirewall/azurerm"

  name                = "fw-arcanum-${local.name_suffix}"
  location            = azurerm_resource_group.root_rg.location
  resource_group_name = azurerm_resource_group.root_rg.name

  firewall_sku_name = "AZFW_VNet"
  firewall_sku_tier = "Standard"

  ip_configurations = {
    primary = {
      name                 = "fw-ipcfg-primary"
      public_ip_address_id = module.firewall_public_ip.resource_id
      subnet_id            = module.lab_vnet.subnets["azurefirewall"].resource_id
    }
  }

  enable_telemetry = false
  tags             = local.tags
}

resource "azurerm_route_table" "egress_via_firewall" {
  name                          = "rt-arcanum-egress-${local.name_suffix}"
  location                      = azurerm_resource_group.root_rg.location
  resource_group_name           = azurerm_resource_group.root_rg.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "default-inet-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.azure_firewall.resource.ip_configuration[0].private_ip_address
  }

  tags = local.tags
}

resource "azurerm_subnet_route_table_association" "service_subnet" {
  subnet_id      = module.lab_vnet.subnets["serviceendpoints"].resource_id
  route_table_id = azurerm_route_table.egress_via_firewall.id
}

resource "azurerm_subnet_route_table_association" "private_endpoint_subnet" {
  subnet_id      = module.lab_vnet.subnets["privateendpoints"].resource_id
  route_table_id = azurerm_route_table.egress_via_firewall.id
}

resource "azurerm_subnet_route_table_association" "general_subnet" {
  subnet_id      = module.lab_vnet.subnets["generalaccess"].resource_id
  route_table_id = azurerm_route_table.egress_via_firewall.id
}

resource "azurerm_network_security_group" "general_access" {
  name                = "nsg-general-access-${local.name_suffix}"
  location            = azurerm_resource_group.root_rg.location
  resource_group_name = azurerm_resource_group.root_rg.name

  security_rule {
    name                       = "allow-rdp-from-bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.200.0.64/28"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh-from-bastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.200.0.64/28"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "general_access" {
  subnet_id                 = module.lab_vnet.subnets["generalaccess"].resource_id
  network_security_group_id = azurerm_network_security_group.general_access.id
}

module "bastion" {
  source = "Azure/avm-res-network-bastionhost/azurerm"

  name      = "bas-arcanum-${local.name_suffix}"
  location  = azurerm_resource_group.root_rg.location
  parent_id = azurerm_resource_group.root_rg.id

  sku = "Standard"

  ip_configuration = {
    name                   = "bastion-ipcfg"
    subnet_id              = module.lab_vnet.subnets["azurebastion"].resource_id
    create_public_ip       = true
    public_ip_address_name = "pip-bastion-arcanum-${local.name_suffix}"
  }

  copy_paste_enabled     = true
  file_copy_enabled      = true
  ip_connect_enabled     = true
  tunneling_enabled      = true
  shareable_link_enabled = false

  enable_telemetry = false
  tags             = local.tags
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.root_rg.name

  tags = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "pdnslink-keyvault-${local.name_suffix}"
  resource_group_name   = azurerm_resource_group.root_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = module.lab_vnet.resource_id
  registration_enabled  = false

  tags = local.tags
}

module "key_vault" {
  source = "Azure/avm-res-keyvault-vault/azurerm"

  name                = local.key_vault_name
  location            = azurerm_resource_group.root_rg.location
  resource_group_name = azurerm_resource_group.root_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  # Purge protection is not needed for this lab environment and only adds complexity when tearing down the environment, so it is disabled here. It should not be disabled in other circumstances.
  purge_protection_enabled = false

  public_network_access_enabled = true
  network_acls = {
    bypass         = "None"
    default_action = "Deny"
    ip_rules       = [var.ADMIN_USER_IPV4_ADDRESS]
    virtual_network_subnet_ids = [
      module.lab_vnet.subnets["serviceendpoints"].resource_id
    ]
  }

  private_endpoints = {
    kv = {
      subnet_resource_id            = module.lab_vnet.subnets["privateendpoints"].resource_id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.keyvault.id]
    }
  }

  enable_telemetry = false
  tags             = local.tags
}

resource "azurerm_role_assignment" "admin_keyvault_data_plane" {
  scope                = "${azurerm_resource_group.root_rg.id}/providers/Microsoft.KeyVault/vaults/${local.key_vault_name}"
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.ADMIN_USER_ID
  principal_type       = "User"

  depends_on = [module.key_vault]
}

resource "random_password" "windows_admin" {
  length           = 24
  special          = true
  override_special = "!@#$%*()-_=+[]{}?"
}

resource "random_password" "linux_admin" {
  length           = 24
  special          = true
  override_special = "!@#$%*()-_=+[]{}?"
}

module "windows_jumpbox" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm"

  name                = "vm-win-jump-${local.name_suffix}"
  location            = azurerm_resource_group.root_rg.location
  resource_group_name = azurerm_resource_group.root_rg.name
  zone                = null

  os_type  = "Windows"
  sku_size = "Standard_B2ms"

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  account_credentials = {
    admin_credentials = {
      username                           = "labadmin"
      password                           = random_password.windows_admin.result
      generate_admin_password_or_ssh_key = false
    }
  }

  network_interfaces = {
    nic1 = {
      name = "nic-win-jump-${local.name_suffix}"
      ip_configurations = {
        ipcfg1 = {
          name                          = "ipcfg-win-jump"
          private_ip_subnet_resource_id = module.lab_vnet.subnets["generalaccess"].resource_id
        }
      }
    }
  }

  enable_telemetry = false
  tags             = local.tags
}

module "linux_jumpbox" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm"

  name                = "vm-linux-jump-${local.name_suffix}"
  location            = azurerm_resource_group.root_rg.location
  resource_group_name = azurerm_resource_group.root_rg.name
  zone                = null

  os_type  = "Linux"
  sku_size = "Standard_B2s"

  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  account_credentials = {
    admin_credentials = {
      username                           = "labadmin"
      password                           = random_password.linux_admin.result
      generate_admin_password_or_ssh_key = false
    }
    password_authentication_disabled = false
  }

  network_interfaces = {
    nic1 = {
      name = "nic-linux-jump-${local.name_suffix}"
      ip_configurations = {
        ipcfg1 = {
          name                          = "ipcfg-linux-jump"
          private_ip_subnet_resource_id = module.lab_vnet.subnets["generalaccess"].resource_id
        }
      }
    }
  }

  enable_telemetry = false
  tags             = local.tags
}

