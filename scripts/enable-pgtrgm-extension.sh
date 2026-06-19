#!/bin/bash

# Enable pg_trgm extension for Azure Database for PostgreSQL Flexible Server
# Resource: https://learn.microsoft.com/en-us/azure/postgresql/extensions/concepts-extensions-versions

set -e

RESOURCE_GROUP="fina-ops"
SERVER_NAME="b4b-staging-db"
EXTENSIONS="vector,pg_trgm"

echo "=== Enabling pg_trgm extension ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Server Name: $SERVER_NAME"
echo "Extensions: $EXTENSIONS"
echo ""

# Set the azure.extensions parameter to include both vector and pg_trgm
echo "Step 1: Updating azure.extensions parameter..."
az postgres flexible-server parameter set \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$SERVER_NAME" \
    --name "azure.extensions" \
    --value "$EXTENSIONS"

echo ""
echo "Step 2: Verifying the parameter update..."
az postgres flexible-server parameter show \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$SERVER_NAME" \
    --name "azure.extensions"

echo ""
echo "=== Extension allowlist updated ==="
echo ""
echo "Next steps:"
echo "1. Connect to each database and run: CREATE EXTENSION IF NOT EXISTS pg_trgm;"
echo ""
echo "Staging database:"
echo "  psql -h $SERVER_NAME.postgres.database.azure.com -U <username> -d finizi_b4b -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'"
echo ""
echo "Production database:"
echo "  psql -h $SERVER_NAME.postgres.database.azure.com -U <username> -d finizi_b4b_production -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'"
