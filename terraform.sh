#!/bin/bash
# Script to create Terraform state storage backend in Azure
# Run this ONCE before running Terraform for the first time

set -e

# Configuration
LOCATION="uksouth"
RESOURCE_GROUP_NAME="rg-terraform-state-prod"
STORAGE_ACCOUNT_NAME="sttfstateprod001"  # Must be globally unique
CONTAINER_NAME="tfstate"

echo "Creating Terraform backend storage..."

# Create resource group
az group create \
  --name $RESOURCE_GROUP_NAME \
  --location $LOCATION \
  --tags "Purpose=TerraformState" "Environment=Shared"

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --location $LOCATION \
  --sku Standard_ZRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --https-only true \
  --encryption-services blob \
  --tags "Purpose=TerraformState" "Environment=Shared"

# Enable versioning for state file protection
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --enable-versioning true \
  --enable-change-feed true

# Create blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login

# Enable soft delete (90 days retention)
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --enable-delete-retention true \
  --delete-retention-days 90 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 90

# Lock the resource group to prevent accidental deletion
az lock create \
  --name "PreventDeletion" \
  --resource-group $RESOURCE_GROUP_NAME \
  --lock-type CanNotDelete \
  --notes "Prevents deletion of Terraform state storage"

echo "Terraform backend storage created successfully!"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Container: $CONTAINER_NAME"
echo ""
echo "Next steps:"
echo "1. Create a service principal for GitHub Actions"
echo "2. Grant the service principal 'Storage Blob Data Contributor' role on the storage account"
echo "3. Configure the backend in your Terraform code"