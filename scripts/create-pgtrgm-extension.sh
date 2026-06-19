#!/bin/bash

# Create pg_trgm extension in Azure Database for PostgreSQL
# Uses Azure CLI to get admin credentials

set -e

RESOURCE_GROUP="fina-ops"
SERVER_NAME="b4b-staging-db"
DB_HOST="$SERVER_NAME.postgres.database.azure.com"

echo "=== Creating pg_trgm extension ==="
echo ""

# Get admin username from Azure
echo "Step 1: Getting database admin username..."
ADMIN_USER=$(az postgres flexible-server show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SERVER_NAME" \
    --query administratorLogin \
    --output tsv)

echo "Admin user: $ADMIN_USER"
echo ""

# Prompt for password
echo "Step 2: Creating extension in databases..."
echo "Enter password for $ADMIN_USER@$DB_HOST:"
read -s DB_PASSWORD
echo ""
echo ""

# Create extension in staging database
echo "Step 3a: Creating pg_trgm in staging database (finizi_b4b)..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$ADMIN_USER" -d finizi_b4b -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

echo ""

# Create extension in production database
echo "Step 3b: Creating pg_trgm in production database (finizi_b4b_production)..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$ADMIN_USER" -d finizi_b4b_production -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

echo ""
echo "=== pg_trgm extension created successfully ==="
echo ""
echo "Verification:"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$ADMIN_USER" -d finizi_b4b -c "SELECT * FROM pg_extension WHERE extname = 'pg_trgm';"
