#!/bin/bash
# uninstall.sh - Completely remove the IaC Wazuh EDR stack and all related components
# Use with caution! This will remove Semaphore, Wazuh components, and optionally dependencies.
set -euo pipefail

log() { echo -e "\033[1;31m[UNINSTALL]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then err "Run as root or with sudo."; fi

log "Stopping and removing Semaphore (Ansible UI)..."
cd ansible-control && docker-compose down -v && cd ..

log "Uninstalling Wazuh components from all managed hosts..."
if [[ -f playbooks/maintenance/uninstall_wazuh.yml ]]; then
  ansible-playbook -i inventory/auto-generator.py playbooks/maintenance/uninstall_wazuh.yml || log "Uninstall playbook failed or not all hosts reachable."
else
  log "No uninstall playbook found. Skipping remote Wazuh removal."
fi

read -p "Remove Ansible, Docker, and all dependencies from this machine? (y/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  log "Removing Ansible, Docker, and dependencies..."
  apt-get remove --purge ansible docker.io docker-compose python3 python3-pip sshpass git -y
  apt-get autoremove -y
fi

log "Removing project files..."
cd ..
rm -rf Infrastructure-as-Code-Wazuh-EDR-

log "Optionally remove SSH keys if they were created for this project."
echo "To remove SSH keys: rm -f /root/.ssh/id_rsa /root/.ssh/id_rsa.pub"

log "Uninstall complete. System purged of IaC Wazuh EDR stack."
