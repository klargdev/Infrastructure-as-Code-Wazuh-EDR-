#!/bin/bash
# deploy.sh - Simple deployment script for Wazuh EDR infrastructure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root or with sudo"
fi

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    err "Ansible is not installed. Please install it first."
fi

# Check if we're in the right directory
if [[ ! -f "playbooks/00_setup_infra.yml" ]]; then
    err "Please run this script from the project root directory"
fi

# Check if inventory exists
if [[ ! -f "inventory/production.ini" ]]; then
    err "Production inventory not found. Please check your inventory configuration."
fi

log "Starting Wazuh EDR infrastructure deployment..."

# Check for certificates
if [[ ! -f "/tmp/wazuh-certificates.tar" ]]; then
    warn "Wazuh certificates not found in /tmp/wazuh-certificates.tar"
    warn "Please ensure you have the required certificates before proceeding"
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
fi

# Run the playbook
log "Running Ansible playbook..."
if ansible-playbook -i inventory/production.ini playbooks/00_setup_infra.yml --verbose; then
    log "Wazuh EDR infrastructure deployed successfully!"
    log ""
    log "Services should be available at:"
    log "  - Wazuh Indexer: https://localhost:9200"
    log "  - Wazuh Dashboard: https://localhost:5601"
    log "  - Wazuh Manager: localhost:1514"
    log ""
    log "Default credentials: admin/admin"
    log ""
    log "You can check service status with:"
    log "  systemctl status wazuh-indexer"
    log "  systemctl status wazuh-dashboard"
    log "  systemctl status wazuh-manager"
    
else
    err "Ansible playbook failed. Please check the output above for errors."
fi
