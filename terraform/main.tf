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
  features {}
  skip_provider_registration = true
  subscription_id            = var.subscription_id
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
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
  name                = "kind_nsg"
  location            = data.azurerm_resource_group.kind.location
  resource_group_name = data.azurerm_resource_group.kind.name

# Security rules to play with. Feel free to change this and to make it shorter.
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

  security_rule {
    name                       = "allow_http_sg"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_https_sg"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_other_sg"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.kind.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Read existing SSH public key
data "local_file" "ssh_public_key" {
  filename = "/home/danijarvis/.ssh/kind.pub"
}

resource "azurerm_linux_virtual_machine" "kind" {
  name                = "playground-kind"
  resource_group_name = data.azurerm_resource_group.kind.name
  location            = data.azurerm_resource_group.kind.location
  size                = "Standard_B2s"
  admin_username      = "kind"
  network_interface_ids = [
    azurerm_network_interface.kind.id,
  ]

  admin_ssh_key {
    username   = "kind"
    public_key = data.local_file.ssh_public_key.content
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

# Installation of Docker, Kind and kubectl for play.
resource "azurerm_virtual_machine_extension" "kind_vm_extension" {
  name                 = "init-script"
  virtual_machine_id   = azurerm_linux_virtual_machine.kind.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = jsonencode({
    "commandToExecute" = <<EOF
#!/bin/bash

# Update package list
sudo apt upgrade -y
sudo apt update -y

# Install Docker
if ! command -v docker &> /dev/null; then
  sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  sudo apt update -y
  sudo apt install -y docker-ce
  sudo usermod -aG docker kind
else
  echo "Docker is already installed"
fi

# Install kind
if ! command -v kind &> /dev/null; then
  if [ "$(uname -m)" = "x86_64" ]; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
  elif [ "$(uname -m)" = "aarch64" ]; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-arm64
  else
    echo "Unsupported architecture: $(uname -m)"
    exit 1
  fi

  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
else
  echo "Kind is already installed"
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl is already installed"
fi

EOF
  })
}


