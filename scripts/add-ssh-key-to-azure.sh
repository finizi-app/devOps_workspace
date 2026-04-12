#!/bin/bash
# add-ssh-key-to-azure.sh - Add your SSH public key to Azure VM
# Usage: ./scripts/add-ssh-key-to-azure.sh [production|staging]

set -e

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo "Azure CLI not installed. Install with:"
    echo "  brew install azure-cli"
    echo ""
    echo "After installation, run 'az login' to authenticate."
    exit 1
fi

# Check logged in
AZ_ACCOUNT=$(az account show --query name -o tsv 2>/dev/null || echo "")
if [ -z "$AZ_ACCOUNT" ]; then
    echo "Not logged in to Azure. Run: az login"
    exit 1
fi

# Configuration
ENVIRONMENT="${1:-production}"
PUBLIC_KEY="${2:-$HOME/.ssh/id_ed25519.pub}"

case "$ENVIRONMENT" in
    production|prod)
        VM_NAME="vm-finizi-prod"
        RG_NAME="fina-ops"
        VM_USER="azureuser"
        ;;
    staging|dev|staging)
        VM_NAME="finizi_dev"
        RG_NAME="fina-ops"
        VM_USER="azureuser"
        ;;
    *)
        echo "Usage: $0 [production|staging] [public_key_path]"
        exit 1
        ;;
esac

# Check public key exists
if [ ! -f "$PUBLIC_KEY" ]; then
    echo "Error: Public key not found at $PUBLIC_KEY"
    exit 1
fi

echo "=== Adding SSH Key to Azure VM ==="
echo "Environment: $ENVIRONMENT"
echo "VM: $VM_NAME"
echo "Resource Group: $RG_NAME"
echo "User: $VM_USER"
echo "Public Key: $PUBLIC_KEY"
echo ""

# Get current keys
echo "Current authorized keys on VM:"
az vm user update --name "$VM_NAME" \
    --resource-group "$RG_NAME" \
    --username "$VM_USER" \
    --ssh-key-value "$(cat $PUBLIC_KEY)"

echo ""
echo "Done! You can now SSH without password:"
echo "  ssh $VM_USER@$(az vm show -n $VM_NAME -g $RG_NAME --query publicIps -o tsv)"
