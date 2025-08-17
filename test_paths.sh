#!/bin/bash
# test_paths.sh - Test script to verify file paths and accessibility

echo "=== Path Testing Script ==="
echo

# Get the directory where this script is located
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script directory: $script_dir"
echo "Current working directory: $(pwd)"
echo

# Test file existence
echo "=== File Existence Tests ==="
files_to_test=(
    "playbooks/00_setup_infra.yml"
    "inventory/production.ini"
    "group_vars/all.yml"
    "roles/common/tasks/main.yml"
    "roles/wazuh_indexer/tasks/main.yml"
    "roles/wazuh_server/tasks/main.yml"
    "roles/wazuh_dashboard/tasks/main.yml"
    "roles/wazuh_agents/tasks/main.yml"
)

for file in "${files_to_test[@]}"; do
    if [[ -f "$script_dir/$file" ]]; then
        echo "✅ $file - EXISTS"
    else
        echo "❌ $file - MISSING"
    fi
done

echo

# Test Ansible syntax
echo "=== Ansible Syntax Check ==="
if command -v ansible-playbook &> /dev/null; then
    echo "✅ Ansible is installed"
    cd "$script_dir"
    if ansible-playbook --syntax-check playbooks/00_setup_infra.yml; then
        echo "✅ Playbook syntax is valid"
    else
        echo "❌ Playbook syntax has errors"
    fi
else
    echo "❌ Ansible is not installed"
fi

echo

# Test inventory
echo "=== Inventory Test ==="
if [[ -f "$script_dir/inventory/production.ini" ]]; then
    echo "✅ Inventory file exists"
    echo "Inventory contents:"
    cat "$script_dir/inventory/production.ini"
else
    echo "❌ Inventory file missing"
fi

echo
echo "=== Path Testing Complete ==="
