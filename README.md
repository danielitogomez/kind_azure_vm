# Provisioning Azure VM with Terraform for Kind and Kubernetes Exploration
This repository contains a Terraform configuration for deploying an Ubuntu VM on Azure. The VM is pre-configured with Docker, Kubernetes (`kind`), and `kubectl`.

## Prerequisites
Before you begin, ensure you have the following installed on your local machine:

- [Terraform](https://www.terraform.io/downloads)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- SSH key pair (public key path: `~/.ssh/kind.pub`)

## Configuration

### Terraform Variables
The following variables need to be set in your Terraform configuration. You can set them directly in the `variables.tf` file or through a `terraform.tfvars` file:

```hcl
variable "resource_group_name" {
  type        = string
  default     = "your_resource_group_name"
  description = "Resource group name in your Azure subscription."
}

variable "subscription_id" {
  type    = string
  default = "your_subscription_id"
}

variable "client_id" {
  type    = string
  default = "your_client_id"
}

variable "client_secret" {
  type    = string
  default = "your_client_secret"
}

variable "tenant_id" {
  type    = string
  default = "your_tenant_id"
}
```
### Azure Authentication
Replace the default values with your actual Azure subscription details. If you are using a CICD it's good idea to manage those as secrets. If you are just playing locally not big deal.

## Deployment Steps

### Authenticate with Azure:
Make sure you are authenticated with Azure CLI, to check stuff like the subscriptionID or some rules that you can to check.

```bash
az login
```

## Initialize Terraform:
Initialize the Terraform configuration. This step downloads the required providers and sets up the backend:

```bash
terraform init
```

## Plan the Deployment:
Generate an execution plan. This step will show you the resources that Terraform will create or modify:

```bash
terraform plan
```

## Apply the Configuration:
Apply the Terraform configuration to create the resources on Azure:

```bash
terraform apply --auto-approve
```

## Access the VM:
Once the deployment is complete, you can SSH into the VM using the public IP address assigned to it. Retrieve the public IP address from the Terraform output or the Azure portal, then connect using:

```bash
eval $(ssh-agent -s) && ssh-add ~/.ssh/<YOUR_PRIATE_KEY>
ssh kind@<public_ip_address>
```

## Resources Created
This Terraform configuration creates the following resources:

- Azure Virtual Network
- Subnet
- Public IP Address
- Network Interface
- Network Security Group with rules for SSH (22), HTTP (80), HTTPS (443), and custom port (8080)
- Linux Virtual Machine with Ubuntu 16.04
- Custom script extension to install Docker, kind, and kubectl

## Custom Script Extension
The VM is configured with a custom script extension to install Docker, kind, and kubectl. The script does the following:

- Updates the package list and upgrades installed packages.
- Installs Docker if it is not already installed.
- Installs kind based on the system architecture.
- Installs kubectl.

## Networking Configuration
The VM is secured with a Network Security Group (NSG) that allows inbound traffic on the following ports:

- SSH (22)
- HTTP (80)
- HTTPS (443)
- Custom port (8080)

Ensure that your local firewall or network security rules allow outbound traffic on these ports.

## Clean Up
To clean up the resources created by this Terraform configuration, run:

```bash
terraform destroy
```

## Additional Notes
- The SSH public key used for the VM is read from `~/.ssh/kind.pub`. Ensure this file exists and contains your SSH public key.
- Modify the Terraform configuration as needed to fit your specific requirements.
- For Kind exploration, refer to the [official KIND documentation](https://kind.sigs.k8s.io/).
- For Kubernetes, refer to the [official Kubernetes documentation](https://kubernetes.io/docs/).

