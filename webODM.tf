# Configure the Azure provider
# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.95.0"
    }
  }
  backend "azurerm" {
    resource_group_name = "odm-rsg"
    #storage_account_name = Stored as a GitHub secret 
    container_name = "tfstates"
    key            = "terraform.tfstate"
  }
}
provider "azurerm" {
  features {}
}
locals {
  common_tags = {
    environment = "${var.repo_nanme}"
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
data "template_file" "user_data" {
  template = file("odmSetup.tpl")
  vars = {
    ssh_key = var.pub_key_data
  }
}
# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rsg"
  location = var.location
  tags     = merge(local.common_tags)
}
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.prefix}-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}
resource "azurerm_virtual_network" "rg" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.rg.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_network_interface" "rg" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  /* when needed to connect to VM */
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
  }
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
}
resource "azurerm_subnet_network_security_group_association" "sec_group" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
resource "azurerm_linux_virtual_machine" "rg" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vmSize
  admin_username      = var.adminUser
  network_interface_ids = [
    azurerm_network_interface.rg.id,
  ]
  computer_name                   = "${var.prefix}-vm"
  disable_password_authentication = true
  custom_data                     = base64encode(data.template_file.user_data.rendered)

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
}
output "azurerm_public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}
