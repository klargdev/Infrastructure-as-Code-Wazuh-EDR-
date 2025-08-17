#!/bin/bash
# install.sh - Bootstrap script for Wazuh EDR Ansible deployment
# Supports Ubuntu 22.04. Installs Ansible, Python3, pip, and sets up SSH keys and inventory.
set -euo pipefail

log() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then err "Run as root or with sudo."; fi


log "Updating and upgrading system packages to latest versions..."
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

log "Installing dependencies (Ansible, Python3, pip, curl)..."
apt-get install -y python3 python3-pip ansible sshpass git curl

log "Setting up SSH keys for Ansible..."
if [[ ! -f /root/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
fi
chmod 600 /root/.ssh/id_rsa


log "Generating initial dynamic inventory..."
python3 inventory/auto-generator.py || err "Inventory generation failed."



# Fix permissions if running in WSL/Linux to ensure ansible.cfg is used
if command -v uname >/dev/null 2>&1 && uname | grep -qiE 'linux|wsl'; then
  chmod o-w "$(pwd)" || true
fi

log "Running Ansible playbook to deploy Wazuh EDR stack..."
if ansible-playbook -i inventory/production.ini playbooks/deploy_wazuh_infra.yml; then
  log "Wazuh EDR stack deployed and configured successfully!"
else
  err "Ansible playbook failed. Please check the output above for errors."
fi
