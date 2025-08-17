#!/bin/bash
# install.sh - Bootstrap script for Wazuh EDR Ansible deployment
# Supports Ubuntu 22.04. Installs Ansible, Docker, Semaphore, and sets up SSH keys and inventory.
set -euo pipefail

log() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then err "Run as root or with sudo."; fi

log "Updating system packages..."
apt-get update -y && apt-get upgrade -y

log "Installing dependencies (Ansible, Python3, pip, Docker, docker-compose)..."
apt-get install -y python3 python3-pip ansible sshpass docker.io docker-compose git

log "Setting up SSH keys for Ansible..."
if [[ ! -f /root/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
fi
chmod 600 /root/.ssh/id_rsa

log "Cloning Semaphore (Ansible UI) Docker setup..."
mkdir -p ansible-control
cp -r $(dirname "$0")/../ansible-control/* ansible-control/ 2>/dev/null || true

log "Starting Semaphore UI with Docker Compose..."
cd ansible-control
if ! docker info >/dev/null 2>&1; then systemctl start docker; fi
docker-compose up -d
cd ..

log "Generating initial dynamic inventory..."
python3 inventory/auto-generator.py || err "Inventory generation failed."

log "Bootstrap complete! Access Semaphore UI at http://localhost:3000"
