#!/bin/bash
# quick_deploy.sh - Simple deployment script for Wazuh EDR

set -e

echo "=== Quick Deploy Wazuh EDR ==="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root or with sudo"
    exit 1
fi

# Get current directory
CURRENT_DIR=$(pwd)
echo "Current directory: $CURRENT_DIR"

# Check if we have the required files
if [[ ! -f "playbooks/00_setup_infra.yml" ]]; then
    echo "❌ Playbook not found. Please run this from the project root directory."
    exit 1
fi

if [[ ! -f "inventory/production.ini" ]]; then
    echo "❌ Inventory not found. Please run this from the project root directory."
    exit 1
fi

echo "✅ All required files found"
echo

# Check if certificates exist
if [[ ! -f "/tmp/wazuh-certificates.tar" ]]; then
    echo "⚠️  Wazuh certificates not found. Generating them now..."
    
    # Create certificates directory
    mkdir -p /tmp/wazuh-certificates
    cd /tmp/wazuh-certificates
    
    # Generate CA private key
    openssl genrsa -out ca.key 4096
    
    # Generate CA certificate
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
        -subj "/C=US/ST=CA/L=San Jose/O=Wazuh/OU=IT/CN=Wazuh-CA"
    
    # Generate server private key
    openssl genrsa -out wazuh-1-key.pem 2048
    
    # Generate server certificate signing request
    openssl req -new -key wazuh-1-key.pem -out wazuh-1.csr \
        -subj "/C=US/ST=CA/L=San Jose/O=Wazuh/OU=IT/CN=wazuh-1"
    
    # Generate server certificate
    openssl x509 -req -in wazuh-1.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out wazuh-1.pem -days 3650
    

    
    # Create certificates archive
    tar -czf /tmp/wazuh-certificates.tar .
    
    # Set proper permissions
    chmod 600 /tmp/wazuh-certificates.tar
    chown root:root /tmp/wazuh-certificates.tar
    
    echo "✅ Certificates generated successfully"
    cd "$CURRENT_DIR"
else
    echo "✅ Certificates already exist"
fi

echo
echo "🚀 Starting Wazuh EDR deployment..."
echo

# Run the Ansible playbook
if ansible-playbook -i inventory/production.ini playbooks/00_setup_infra.yml --verbose; then
    echo
    echo "🎉 Wazuh EDR deployment completed successfully!"
    echo
    echo "Services should be available at:"
    echo "  - Wazuh Indexer: https://localhost:9200"
    echo "  - Wazuh Dashboard: https://localhost:5601"
    echo "  - Wazuh Manager: localhost:1514"
    echo
    echo "Default credentials: admin/admin"
    echo
    echo "Check service status with:"
    echo "  systemctl status wazuh-*"
else
    echo
    echo "❌ Deployment failed. Please check the output above for errors."
    exit 1
fi
