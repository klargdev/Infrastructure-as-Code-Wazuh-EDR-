#!/usr/bin/env python3
"""
auto-generator.py - Dynamic inventory generator for Wazuh EDR
Scans environment variables or config files to produce Ansible inventory in INI format.
"""
import os, sys, json

def log(msg):
    print(f"[INFO] {msg}")

def err(msg):
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(1)

def get_hosts():
    # Example: read from environment or config file
    hosts = os.environ.get('WAZUH_HOSTS')
    if hosts:
        return hosts.split(',')
    # Fallback: static config
    return ['server1', 'indexer1', 'dashboard1']

def main():
    try:
        hosts = get_hosts()
        inventory = {
            'wazuh_server': {'hosts': [hosts[0]]},
            'wazuh_indexer': {'hosts': [hosts[1]]},
            'wazuh_dashboard': {'hosts': [hosts[2]]},
        }
        print(json.dumps(inventory))
    except Exception as e:
        err(f"Failed to generate inventory: {e}")

if __name__ == "__main__":
    main()
