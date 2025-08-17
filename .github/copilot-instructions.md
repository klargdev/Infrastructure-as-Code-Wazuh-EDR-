# Copilot Instructions for Infrastructure-as-Code-Wazuh-EDR-

## Project Overview
This repository manages the automated deployment and configuration of a Wazuh EDR (Endpoint Detection and Response) stack using Ansible. It provisions and configures Wazuh Server, Indexer, Dashboard, and Agents, supporting multiple environments (development, staging, production).

## Architecture & Structure
- **playbooks/**: Main entry points for provisioning (e.g., `deploy_wazuh_infra.yml`, `deploy_server.yml`).
- **roles/**: Modular Ansible roles for each component:
  - `wazuh_server/`, `wazuh_indexer/`, `wazuh_dashboard/`, `wazuh_agents/`, `common/`
- **group_vars/** & **host_vars/**: Environment and host-specific configuration.
- **files/**: Static files (e.g., SSL certs, custom rules).
- **scripts/**: Utility scripts for validation, health checks, and password generation.
- **tests/**: Integration and Molecule tests for deployment validation.

## Key Workflows
- **Deploy full stack:**
  ```sh
  ansible-playbook -i inventory/development.ini playbooks/deploy_wazuh_infra.yml
  ```
- **Deploy/update individual components:**
  Use the corresponding playbook in `playbooks/` (e.g., `deploy_dashboard.yml`).
- **Run health checks:**
  ```sh
  python scripts/health_check.py
  ```
- **Validate configs:**
  ```sh
  bash scripts/validate_configs.sh
  ```
- **Run tests:**
  - Integration: `pytest tests/integration/`
  - Molecule: `cd tests/molecule/default && molecule test`

## Project Conventions
- **Role structure:** Each role has `tasks/`, `handlers/`, `vars/`, and `templates/`.
- **YAML config:** All Ansible variables and inventory use YAML format.
- **Secrets:** Sensitive files (e.g., SSL keys) are stored in `files/ssl/` and referenced via variables.
- **Templates:** Jinja2 templates for config files are in `roles/*/templates/`.
- **Environment separation:** Use `inventory/` and `group_vars/` to manage per-environment settings.

## Integration Points
- **Wazuh components communicate via configured hostnames/IPs and SSL.**
- **External dependencies:**
  - Ansible (see `requirements.txt` for collections/roles)
  - Python for scripts and tests
  - Bash for some utility scripts

## Examples
- To add a new agent, update `inventory/` and run `playbooks/deploy_agents.yml`.
- To customize Wazuh rules, edit `files/wazuh/custom_rules.xml` and redeploy the server.

## References
- See `README.md` for high-level project info.
- See `docs/` for architecture, configuration, and troubleshooting guides.

---
**For AI agents:**
- Prefer updating roles and playbooks over ad-hoc scripts.
- Follow existing directory and naming conventions.
- Reference `docs/` for detailed component interactions and troubleshooting.
