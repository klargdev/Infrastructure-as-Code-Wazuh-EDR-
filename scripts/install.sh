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



# Wait for Semaphore to be up and healthy
log "Waiting for Semaphore to start (this may take up to 60 seconds)..."
for i in {1..30}; do
  if curl -s http://localhost:3000 >/dev/null; then
    log "Semaphore UI is up."
    break
  fi
  sleep 2
  if [[ $i -eq 30 ]]; then err "Semaphore UI did not start in time."; fi
done

# Retry CLI project creation until successful
log "Configuring Semaphore for one-click Wazuh EDR deployment..."
for i in {1..5}; do
  docker exec semaphore semaphore user add --admin --login admin --name "Admin" --email admin@localhost --password changeme 2>/dev/null || true
  docker exec semaphore semaphore project add --name "IaC EDR" 2>/dev/null && break
  sleep 2
  if [[ $i -eq 5 ]]; then err "Failed to create Semaphore project after multiple attempts."; fi
done

# Get project ID for "IaC EDR"
PROJECT_ID=$(docker exec semaphore semaphore project list | awk '/IaC EDR/ {print $1}' | head -n1)
if [[ -z "$PROJECT_ID" ]]; then err "Could not find IaC EDR project in Semaphore."; fi

# Add inventory and template
docker exec semaphore semaphore inventory add --project "$PROJECT_ID" --name "Dynamic Inventory" --type plugin --inventory /inventory/auto-generator.py || true
docker exec semaphore semaphore template add --project "$PROJECT_ID" --name "Deploy Full Stack" --playbook /playbooks/00_setup_infra.yml --inventory 1 || true

# Trigger the playbook run (deploy Wazuh EDR stack)
docker exec semaphore semaphore task add --template 1 --environment 1 --inventory 1 --project "$PROJECT_ID" || true

log "Bootstrap complete! Semaphore and Wazuh EDR stack are fully deployed and ready!"
log "Access the Semaphore UI at:   http://localhost:3000"
log "Access the Wazuh Dashboard at: https://dashboard1:5601 (or your configured dashboard host)"
