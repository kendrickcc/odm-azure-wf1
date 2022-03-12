#-------------------------------
# Terraform provider and backend
#-------------------------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.95.0"
    }
  }
  #/* disabling the backend
  backend "azurerm" {
    resource_group_name = "odm-rsg"
    #storage_account_name = Stored as a GitHub secret 
    container_name = "tfstates"
    key            = "terraform.tfstate"
  } # */
}
provider "azurerm" {
  features {}
}
#-------------------------------
# Define tags, edit in variables
#------------------------------
locals {
  common_tags = {
    environment = "${var.repo_name}"
    project     = "${var.project}"
    Owner       = "${var.repo_owner}"
  }
  /*
  extra_tags  = {
    network = "${var.network1_name}"
    support = "${var.network_support_name}"
  }*/
}
#-------------------------------
# Get cloud-init template file
#-------------------------------
data "template_file" "webodm" {
  template = file("webodm.tpl")
  vars = {
    ssh_key = var.pub_key_data
  }
}
data "template_file" "nodeodm" {
  template = file("nodeodm.tpl")
  vars = {
    ssh_key = var.pub_key_data
  }
}
#-------------------------------
# Create resource group
#-------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rsg"
  location = var.location
  tags     = merge(local.common_tags)
}
#-------------------------------
# Networking
#-------------------------------
resource "azurerm_public_ip" "webodm" {
  name                = "${var.prefix}-webodm${count.index}-pip"
  count = var.webodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"
  tags                = merge(local.common_tags)
}
resource "azurerm_public_ip" "nodeodm" {
  name                = "${var.prefix}-nodeodm${count.index}-pip"
  count = var.nodeodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"
  tags                = merge(local.common_tags)
}
resource "azurerm_virtual_network" "rg" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = merge(local.common_tags)
}
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.rg.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_network_interface" "webodm" {
  name                = "${var.prefix}-webodm${count.index}-nic"
  count               = var.webodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webodm[count.index].id
  }
  tags = merge(local.common_tags)
}
resource "azurerm_network_interface" "nodeodm" {
  name                = "${var.prefix}-nodeodm${count.index}-nic"
  count               = var.nodeodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nodeodm[count.index].id
  }
  tags = merge(local.common_tags)
}
#-------------------------------
# Network security group
#-------------------------------
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = merge(local.common_tags)
  # /* when needed to connect to VM 
  security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  } # */
  security_rule {
    name                       = "AllowWebODMInBound"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowClusterODMInBound"
    priority                   = 401
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8001"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "sec_group" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
#-------------------------------
# Create virtual machines
#-------------------------------
resource "azurerm_linux_virtual_machine" "webodm" {
  name                = "${var.prefix}-webodm${count.index}-vm"
  count               = var.webodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vmSize
  admin_username      = var.adminUser
  network_interface_ids = [
    azurerm_network_interface.webodm[count.index].id,
  ]
  computer_name                   = "${var.prefix}-webodm${count.index}-vm"
  disable_password_authentication = true
  custom_data                     = base64encode(data.template_file.webodm.rendered)

  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = var.skuVersion
  }
  os_disk {
    storage_account_type = var.storageAccountType
    caching              = "ReadWrite"
    disk_size_gb         = var.diskSizeGB
  }
  admin_ssh_key {
    username   = var.adminUser
    public_key = var.pub_key_data
  }
  tags = merge(local.common_tags)
}
resource "azurerm_linux_virtual_machine" "nodeodm" {
  name                = "${var.prefix}-nodeodm${count.index}-vm"
  count               = var.nodeodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vmSize
  admin_username      = var.adminUser
  network_interface_ids = [
    azurerm_network_interface.nodeodm[count.index].id,
  ]
  computer_name                   = "${var.prefix}-nodeodm${count.index}-vm"
  disable_password_authentication = true
  custom_data                     = base64encode(data.template_file.nodeodm.rendered)

  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = var.skuVersion
  }
  os_disk {
    storage_account_type = var.storageAccountType
    caching              = "ReadWrite"
    disk_size_gb         = var.diskSizeGB
  }
  admin_ssh_key {
    username   = var.adminUser
    public_key = var.pub_key_data
  }
  tags = merge(local.common_tags)
}
#-------------------------------
# Outputs
#-------------------------------
output "WebODM_public_ip_port_8000" {
  value = azurerm_linux_virtual_machine.webodm.*.public_ip_addresses
}
output "ClusterODM_private_ip_addresses_port_8001" {
  value = azurerm_linux_virtual_machine.webodm.*.private_ip_addresses
}
output "NodeODM_private_ip_addresses_port_3000" {
  value = azurerm_linux_virtual_machine.nodeodm.*.private_ip_addresses
}
