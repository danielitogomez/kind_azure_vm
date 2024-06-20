terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.53.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
}

data "azurerm_resource_group" "kind" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "kind" {
  name                = "kind-network"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.kind.location
  resource_group_name = data.azurerm_resource_group.kind.name
}

resource "azurerm_subnet" "kind" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.kind.name
  virtual_network_name = azurerm_virtual_network.kind.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "vm_public_ip"
  resource_group_name = data.azurerm_resource_group.kind.name
  location            = data.azurerm_resource_group.kind.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "kind" {
  name                = "kind-nic"
  location            = data.azurerm_resource_group.kind.location
  resource_group_name = data.azurerm_resource_group.kind.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.kind.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "ssh_nsg"
  location            = data.azurerm_resource_group.kind.location
  resource_group_name = data.azurerm_resource_group.kind.name

  security_rule {
    name                       = "allow_ssh_sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.kind.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create (and display) an SSH key
resource "tls_private_key" "kind_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "kind" {
  name                = "multicloud-poc-machine"
  resource_group_name = data.azurerm_resource_group.kind.name
  location            = data.azurerm_resource_group.kind.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.kind.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.kind_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "kind_vm_extension" {
  name                 = "init-script"
  virtual_machine_id   = azurerm_linux_virtual_machine.kind.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = jsonencode({
    "commandToExecute" = "#echo command are here"
  })
}