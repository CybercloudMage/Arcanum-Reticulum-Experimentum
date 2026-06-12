# Arcanum-Reticulum-Experimentum

This repository deploys a full Azure lab environment through Terraform and is intended to be safely re-run from GitHub workflows for create and update operations.

## Design goals

- No required workflow-provided Terraform variables.
- All resources are created under a single root resource group (`azurerm_resource_group.root_rg`) for easy teardown.
- Azure Verified Modules (AVM) are used for core platform resources.

## Deployed architecture

- Resource Group (`root_rg`)
- Virtual Network (`10.200.0.0/16`) via AVM
- Subnets
	- `AzureFirewallSubnet`: `10.200.0.0/26`
	- `AzureBastionSubnet`: `10.200.0.64/28`
	- Service Endpoints subnet: `10.200.1.0/24`
	- Private Endpoints subnet: `10.200.2.0/24`
	- General Access subnet: `10.200.3.0/24`
- Azure Firewall (AVM) with Standard SKU as controlled egress gateway
- Route table forcing default egress (`0.0.0.0/0`) from workload subnets through Azure Firewall
- Azure Bastion (AVM) for secure administration access to internal hosts
- Azure Key Vault (AVM) with public access disabled and private endpoint only
- Two jump-box VMs (AVM)
	- Windows Server (GUI-capable marketplace image)
	- Ubuntu Server

## Network and security notes

- Subnets are configured with `default_outbound_access_enabled = false`.
- Workload subnet default routes are sent to Azure Firewall.
- General access subnet NSG only permits management inbound from `AzureBastionSubnet` on TCP `3389` and `22`.
- Key Vault private DNS zone (`privatelink.vaultcore.azure.net`) is created and linked to the lab VNet.
- Secure DNS forwarders (`9.9.9.9`, `1.1.1.1`) are configured on the VNet.

## Default configuration

Defaults are baked into Terraform variables so deployments can run without additional workflow input.

- `ENVIRONMENT = "dev"`
- `RESOURCE_GROUP_NAME = "rg-arcanum-reticulum-lab"`
- `RESOURCE_GROUP_LOCATION = "eastus2"`
- `ENABLE_ADMIN_ROLE_ASSIGNMENTS = false` (set to `true` only when the deploying identity can manage `Microsoft.Authorization/roleAssignments/*`)

## Usage

```bash
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

## Teardown

Because all assets are under `root_rg`, deleting the resource group removes the full lab environment.
