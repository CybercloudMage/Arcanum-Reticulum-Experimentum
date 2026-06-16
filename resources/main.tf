# Gathering the various data elements that will be needed for these resource definitions
data "azurerm_resource_group" "root" {
  name = var.AZURE_ROOT_RESOURCE_GROUP_NAME
}

data "azurerm_virtual_network" "root" {
  name                = var.AZURE_ROOT_VIRTUAL_NETWORK_NAME
  resource_group_name = data.azurerm_resource_group.root.name
}

data "azurerm_key_vault" "root" {
  name                = var.AZURE_KEY_VAULT_NAME
  resource_group_name = data.azurerm_resource_group.root.name
}

data "azurerm_subnet" "vm_admin" {
  name                 = var.AZURE_VM_SUBNET_NAME
  virtual_network_name = data.azurerm_virtual_network.root.name
  resource_group_name  = data.azurerm_resource_group.root.name
}

data "azurerm_subnet" "bastion" {
  name                 = var.AZURE_BASTION_SUBNET_NAME
  virtual_network_name = data.azurerm_virtual_network.root.name
  resource_group_name  = data.azurerm_resource_group.root.name
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.ENVIRONMENT}-001"
  location            = data.azurerm_resource_group.root.location
  resource_group_name = data.azurerm_resource_group.root.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "main" {
  name                = "bas-${var.ENVIRONMENT}-001"
  location            = data.azurerm_resource_group.root.location
  resource_group_name = data.azurerm_resource_group.root.name
  sku                 = var.AZURE_BASTION_SKU

  ip_configuration {
    name                 = "configuration"
    subnet_id            = data.azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "random_password" "windows_admin" {
  length           = 24
  special          = true
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "tls_private_key" "ubuntu_admin" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "windows_admin_password" {
  name         = "vm-win-admin-password-${var.ENVIRONMENT}"
  value        = random_password.windows_admin.result
  key_vault_id = data.azurerm_key_vault.root.id

  content_type = "Windows VM local admin password"
}

resource "azurerm_key_vault_secret" "ubuntu_ssh_private_key" {
  name         = "vm-ubuntu-ssh-private-key-${var.ENVIRONMENT}"
  value        = tls_private_key.ubuntu_admin.private_key_pem
  key_vault_id = data.azurerm_key_vault.root.id

  content_type = "Ubuntu VM SSH private key"
}

resource "azurerm_key_vault_secret" "ubuntu_ssh_public_key" {
  name         = "vm-ubuntu-ssh-public-key-${var.ENVIRONMENT}"
  value        = tls_private_key.ubuntu_admin.public_key_openssh
  key_vault_id = data.azurerm_key_vault.root.id

  content_type = "Ubuntu VM SSH public key"
}

resource "azurerm_network_interface" "windows" {
  name                = "nic-win-${var.ENVIRONMENT}-001"
  location            = data.azurerm_resource_group.root.location
  resource_group_name = data.azurerm_resource_group.root.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.vm_admin.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "ubuntu" {
  name                = "nic-ubuntu-${var.ENVIRONMENT}-001"
  location            = data.azurerm_resource_group.root.location
  resource_group_name = data.azurerm_resource_group.root.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.vm_admin.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "windows" {
  name                = "vm-win-${var.ENVIRONMENT}-001"
  computer_name       = "win${var.ENVIRONMENT}001"
  location            = data.azurerm_resource_group.root.location
  resource_group_name = data.azurerm_resource_group.root.name
  size                = var.WINDOWS_VM_SIZE
  admin_username      = var.WINDOWS_VM_ADMIN_USERNAME
  admin_password      = random_password.windows_admin.result

  network_interface_ids = [azurerm_network_interface.windows.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "ubuntu" {
  name                            = "vm-ubuntu-${var.ENVIRONMENT}-001"
  computer_name                   = "ubn${var.ENVIRONMENT}001"
  location                        = data.azurerm_resource_group.root.location
  resource_group_name             = data.azurerm_resource_group.root.name
  size                            = var.UBUNTU_VM_SIZE
  admin_username                  = var.UBUNTU_VM_ADMIN_USERNAME
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.ubuntu.id]

  admin_ssh_key {
    username   = var.UBUNTU_VM_ADMIN_USERNAME
    public_key = tls_private_key.ubuntu_admin.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

