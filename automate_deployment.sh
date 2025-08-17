#!/bin/bash
# automate_deployment.sh - Complete automation for Wazuh EDR deployment
# This script automates the entire process from system preparation to deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WAZUH_VERSION="4.12"
WAZUH_INSTALL_URL="https://packages.wazuh.com/4.12/wazuh-install.sh"
CERTIFICATES_DIR="/tmp/wazuh-certificates"
BACKUP_DIR="/var/backups/wazuh"

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root or with sudo"
fi

# Function to check system requirements
check_system_requirements() {
    step "Checking system requirements..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        err "Cannot determine operating system"
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "22.04" ]]; then
        warn "This script is tested on Ubuntu 22.04. Current OS: $ID $VERSION_ID"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Check available memory
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_total / 1024 / 1024))
    if [[ $mem_gb -lt 4 ]]; then
        err "Insufficient memory. Required: 4GB, Available: ${mem_gb}GB"
    fi
    
    # Check available disk space
    local disk_space=$(df / | awk 'NR==2 {print $4}')
    local disk_gb=$((disk_space / 1024 / 1024))
    if [[ $disk_gb -lt 10 ]]; then
        err "Insufficient disk space. Required: 10GB, Available: ${disk_gb}GB"
    fi
    
    log "System requirements check passed"
}

# Function to install system dependencies
install_dependencies() {
    step "Installing system dependencies..."
    
    # Update system
    apt-get update -y
    
    # Install required packages
    apt-get install -y \
        python3 \
        python3-pip \
        ansible \
        curl \
        wget \
        unzip \
        tar \
        gnupg \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        openjdk-17-jdk \
        libxml2-utils \
        ufw
    
    # Install Ansible collections
    ansible-galaxy collection install ansible.posix
    ansible-galaxy collection install community.general
    
    log "Dependencies installed successfully"
}

# Function to generate self-signed certificates
generate_certificates() {
    step "Generating self-signed certificates..."
    
    # Store current directory
    local current_dir=$(pwd)
    
    # Create certificates directory
    mkdir -p "$CERTIFICATES_DIR"
    cd "$CERTIFICATES_DIR"
    
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
    
    # Return to original directory
    cd "$current_dir"
    
    log "Certificates generated successfully"
}

# Function to configure firewall
configure_firewall() {
    step "Configuring firewall..."
    
    # Enable UFW
    ufw --force enable
    
    # Allow SSH
    ufw allow ssh
    
    # Allow Wazuh ports
    ufw allow 1514/tcp  # Wazuh manager
    ufw allow 1515/tcp  # Wazuh cluster
    ufw allow 9200/tcp  # Wazuh indexer
    ufw allow 5601/tcp  # Wazuh dashboard
    
    # Allow HTTP/HTTPS for updates
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    log "Firewall configured successfully"
}

# Function to prepare system for Wazuh
prepare_system() {
    step "Preparing system for Wazuh..."
    
    # Set system limits
    cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
    
    # Set kernel parameters
    cat >> /etc/sysctl.conf << EOF
vm.max_map_count=262144
vm.swappiness=1
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
EOF
    
    # Apply sysctl changes
    sysctl -p
    
    # Create Wazuh user and directories
    useradd -r -s /bin/false -d /var/ossec wazuh || true
    mkdir -p /var/ossec/{logs,stats,var}
    chown -R wazuh:wazuh /var/ossec
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    log "System prepared successfully"
}

# Function to run Ansible deployment
run_ansible_deployment() {
    step "Running Ansible deployment..."
    
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    log "Script directory: $script_dir"
    log "Current working directory: $(pwd)"
    
    # Check if we're in the right directory or if the script is in the right place
    if [[ ! -f "$script_dir/playbooks/00_setup_infra.yml" ]]; then
        err "Playbook not found at $script_dir/playbooks/00_setup_infra.yml"
    fi
    
    # Check if inventory exists
    if [[ ! -f "$script_dir/inventory/production.ini" ]]; then
        err "Production inventory not found at $script_dir/inventory/production.ini"
    fi
    
    log "Playbook found at: $script_dir/playbooks/00_setup_infra.yml"
    log "Inventory found at: $script_dir/inventory/production.ini"
    
    # Change to the script directory to run the playbook
    cd "$script_dir"
    log "Changed to directory: $(pwd)"
    
    # Verify we're in the right place
    if [[ ! -f "playbooks/00_setup_infra.yml" ]]; then
        err "Failed to change to correct directory. Current: $(pwd)"
    fi
    
    # Run the playbook
    if ansible-playbook -i inventory/production.ini playbooks/00_setup_infra.yml --verbose; then
        log "Ansible deployment completed successfully!"
    else
        err "Ansible deployment failed"
    fi
}

# Function to verify deployment
verify_deployment() {
    step "Verifying deployment..."
    
    # Check services
    local services=("wazuh-manager" "wazuh-indexer" "wazuh-dashboard")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "$service is running"
        else
            warn "$service is not running"
        fi
    done
    
    # Check ports
    local ports=("1514" "9200" "5601")
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            log "Port $port is listening"
        else
            warn "Port $port is not listening"
        fi
    done
    
    # Test Wazuh Indexer
    if curl -k -u admin:admin https://localhost:9200/_cluster/health 2>/dev/null | grep -q "green\|yellow"; then
        log "Wazuh Indexer is responding"
    else
        warn "Wazuh Indexer is not responding"
    fi
    
    log "Deployment verification completed"
}

# Function to display final information
display_final_info() {
    step "Deployment completed successfully!"
    echo
    echo "Wazuh EDR Infrastructure is now deployed and running."
    echo
    echo "Services:"
    echo "  - Wazuh Indexer: https://localhost:9200"
    echo "  - Wazuh Dashboard: https://localhost:5601"
    echo "  - Wazuh Manager: localhost:1514"
    echo
    echo "Default credentials: admin/admin"
    echo
    echo "Useful commands:"
    echo "  - Check service status: systemctl status wazuh-*"
    echo "  - View logs: journalctl -u wazuh-manager -f"
    echo "  - Check agent status: /var/ossec/bin/agent_control -l"
    echo
    echo "Certificates are stored in: $CERTIFICATES_DIR"
    echo "Backups are stored in: $BACKUP_DIR"
    echo
    echo "Next steps:"
    echo "  1. Access the Wazuh Dashboard at https://localhost:5601"
    echo "  2. Log in with admin/admin"
    echo "  3. Configure your first agent"
    echo "  4. Review and customize security policies"
}

# Main execution
main() {
    echo "=========================================="
    echo "Wazuh EDR Infrastructure Automation Script"
    echo "=========================================="
    echo
    
    # Store the original directory where the script was called from
    local original_dir=$(pwd)
    log "Original working directory: $original_dir"
    
    # Check system requirements
    check_system_requirements
    
    # Install dependencies
    install_dependencies
    
    # Generate certificates
    generate_certificates
    
    # Configure firewall
    configure_firewall
    
    # Prepare system
    prepare_system
    
    # Run Ansible deployment
    run_ansible_deployment
    
    # Return to original directory
    cd "$original_dir"
    log "Returned to original directory: $(pwd)"
    
    # Verify deployment
    verify_deployment
    
    # Display final information
    display_final_info
}

# Run main function
main "$@"
