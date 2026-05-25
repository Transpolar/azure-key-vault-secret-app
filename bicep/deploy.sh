#!/bin/bash
set -e

# ============================================
# Azure Key Vault Demo - Bicep Deployment
# ----------------------------------------------
# Deploys the infrastructure declared in main.bicep
# and then publishes the .NET app in ./src to the
# resulting App Service.
# ============================================

RG_NAME="keyvault-demo-rg"
LOCATION="norwayeast"
PUBLISH_DIR=".publish"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Azure Key Vault Demo - Bicep Deployment"
echo "=========================================="
echo "Resource Group : $RG_NAME"
echo "Location       : $LOCATION"
echo "=========================================="

# ============================================
# 1. Resource group
# ============================================
echo ""
echo "[1/4] Creating resource group..."
az group create --name "$RG_NAME" --location "$LOCATION" --output none

# ============================================
# 2. Deploy infrastructure via Bicep
# ============================================
echo "[2/4] Deploying Bicep template (this takes ~2-3 minutes)..."
DEPLOYMENT_OUTPUTS=$(az deployment group create \
  --resource-group "$RG_NAME" \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --query 'properties.outputs' \
  -o json)

WEB_APP_NAME=$(echo "$DEPLOYMENT_OUTPUTS" | jq -r '.webAppName.value')
WEB_APP_URL=$(echo "$DEPLOYMENT_OUTPUTS"  | jq -r '.webAppUrl.value')
KV_NAME=$(echo "$DEPLOYMENT_OUTPUTS"      | jq -r '.keyVaultName.value')

echo "Web App   : $WEB_APP_NAME"
echo "Key Vault : $KV_NAME"

# ============================================
# 3. Build & publish the .NET app
# ============================================
echo "[3/4] Building .NET application..."
rm -rf "$PUBLISH_DIR"
dotnet publish ./src -c Release -o "$PUBLISH_DIR" > /dev/null

(cd "$PUBLISH_DIR" && zip -rq ../app.zip .)

# ============================================
# 4. Deploy the .NET app
# ============================================
echo "[4/4] Deploying .NET application to App Service..."
az webapp deployment source config-zip \
  --src app.zip \
  --resource-group "$RG_NAME" \
  --name "$WEB_APP_NAME" \
  --output none

rm -rf "$PUBLISH_DIR" app.zip

# ============================================
# DONE
# ============================================
echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETE"
echo "=========================================="
echo ""
echo "App URL      : $WEB_APP_URL"
echo "Key Vault    : $KV_NAME"
echo "Resource Grp : $RG_NAME"
echo ""
echo "Wait ~60 seconds for the app to start, then visit the URL."
echo ""
echo "View logs:"
echo "  az webapp log tail --name $WEB_APP_NAME --resource-group $RG_NAME"
echo ""
echo "Clean up all resources:"
echo "  az group delete --name $RG_NAME --yes --no-wait"
echo ""
