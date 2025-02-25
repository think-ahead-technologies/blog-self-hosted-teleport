#!/bin/bash

# Variables
resource_group="selfhosted-teleport-mgmt"
location="germanywestcentral"
storage_account_name="tfstate$(date +%s)" # Ensure uniqueness
container_name="terraform-state"

echo "Creating resource group $resource_group..."
az group create --name $resource_group --location $location

# Step 2: Create the storage account for Terraform state
echo "Creating storage account $storage_account_name..."
az storage account create \
	--name "$storage_account_name" \
	--resource-group $resource_group \
	--location $location \
	--sku Standard_LRS \
	--encryption-services blob

# Step 3: Retrieve the storage account key
account_key=$(az storage account keys list \
	--resource-group $resource_group \
	--account-name "$storage_account_name" \
	--query "[0].value" -o tsv)

# Step 4: Create the blob container for Terraform state
echo "Creating blob container $container_name..."
az storage container create \
	--name $container_name \
	--account-name "$storage_account_name" \
	--account-key "$account_key"

# Output Terraform backend configuration details
echo "Terraform backend configuration:"
echo "Resource Group: $resource_group"
echo "Storage Account Name: $storage_account_name"
echo "Container Name: $container_name"