#!/bin/bash
# Automated Wazuh EDR All-in-One Setup Script
# Usage: ./setup.sh
set -e

# Print banner
echo "\n=== Wazuh EDR Automated Single-Node Setup ===\n"

# Check for root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo $0)" >&2
  exit 1
fi

# Install dependencies
apt update
apt install -y python3 python3-pip ansible curl gnupg apt-transport-https

# Run Ansible playbook
ansible-playbook -i inventory/production.ini playbooks/deploy_wazuh_infra.yml

# Print service URLs
cat <<EOF

---
Wazuh EDR stack deployed!

Access the Wazuh Dashboard at: https://localhost
  (Default user: admin / password: admin)

Wazuh Indexer API: https://localhost:9200
Wazuh Manager API: https://localhost:55000

Note: Certificates are self-signed. Accept the browser warning on first login.
---
EOF
