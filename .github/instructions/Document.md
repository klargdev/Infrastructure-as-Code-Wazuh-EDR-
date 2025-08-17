Author: [Lartey Kpabitey Gabriel ]
Date: [YYYY-MM-DD]
Version: 1.0

1. Project Overview
This project automates the deployment and configuration of Wazuh EDR (Endpoint Detection and Response) using Ansible (Infrastructure as Code). The solution includes:

Wazuh Indexer (OpenSearch-based log storage)

Wazuh Server (Manager for threat detection & rules)

Wazuh Dashboard (OpenSearch Dashboards for visualization)

Agent Auto-Deployment (For endpoints)

Key Objectives
✔ Automate deployment to reduce manual errors & deployment time
✔ Standardize configurations for consistency across environments
✔ Minimize technical overhead for SMEs and startups
✔ Provide a scalable and repeatable EDR solution

2. System Architecture
High-Level Diagram
text
[ Endpoints (Agents) ] → [ Wazuh Server ] → [ Wazuh Indexer ] → [ Wazuh Dashboard ]
Components
Component	Role
Wazuh Indexer	Stores and indexes security logs (OpenSearch-based)
Wazuh Server	Processes alerts, runs rules, and manages agents
Wazuh Dashboard	Web UI for visualizing threats (OpenSearch Dashboards)
Ansible Controller	Automates deployment and configuration
3. File Structure & Ansible Roles
Core Ansible Roles
Role	Purpose
common	Base setup (firewall, dependencies)
wazuh_indexer	Deploys OpenSearch cluster
wazuh_server	Configures Wazuh Manager
wazuh_dashboard	Sets up OpenSearch Dashboards
wazuh_agents	Automates agent installation
Key Playbooks
Playbook	Usage
deploy_wazuh_infra.yml	Full deployment (Indexer + Server + Dashboard)
deploy_agents.yml	Deploys Wazuh agents on endpoints
maintenance/upgrade.yml	Updates Wazuh components
4. Deployment Steps
1. Prerequisites
Ansible (>= 2.12) installed on the control node

SSH access to target servers (Linux-based)

Python 3 on all hosts

2. Configuration
Inventory Setup (inventory/production.ini)
ini
[wazuh_indexer]
indexer1 ansible_host=192.168.1.10

[wazuh_server]
server1 ansible_host=192.168.1.11

[wazuh_dashboard]
dashboard1 ansible_host=192.168.1.12
Variables (group_vars/all.yml)
yaml
wazuh_version: "4.7.2"
opensearch_version: "2.10.0"
3. Running Deployment
bash
ansible-playbook -i inventory/production.ini playbooks/deploy_wazuh_infra.yml
5. Security & Hardening
SSL/TLS Setup
Certificates stored in files/ssl/

Auto-configured in OpenSearch & Dashboard roles

Firewall Rules
Ansible configures ufw/firewalld (in common role)

Authentication
Wazuh Dashboard uses JWT-based auth

OpenSearch security plugin enabled

6. Testing & Validation
Automated Tests
Molecule for role testing (tests/molecule/)

Integration tests (tests/integration/)

Manual Checks
bash
curl -k https://dashboard1:5601  # Verify Dashboard
systemctl status wazuh-manager   # Check Wazuh Server
7. Maintenance & Scaling
Backup & Restore
Playbook: playbooks/maintenance/backup.yml

Backs up:

OpenSearch indices

Wazuh configurations

Scaling
Horizontal scaling by adding more indexer nodes

Agent auto-registration via wazuh_agents role

8. Troubleshooting
Issue	Solution
Wazuh Dashboard not loading	Check OpenSearch logs (/var/log/opensearch/)
Agents not connecting	Verify ossec.conf and firewall rules
High CPU on Indexer	Optimize JVM heap in opensearch.yml.j2
9. Future Enhancements
Cloud integration (AWS/Azure auto-scaling)

SIEM integrations (Slack, Splunk, TheHive)

Compliance checks (CIS benchmarks automation)

10. Conclusion
This Ansible-based IaC solution provides:
✅ Faster deployment (vs manual setup)
✅ Consistent security posture
✅ Cost-effective EDR for SMEs

Next Steps:

Customize group_vars for your environment

Deploy using deploy_wazuh_infra.yml

Monitor via Wazuh Dashboard

Appendices
Official Wazuh links: 
https://documentation.wazuh.com/current/getting-started/index.html#getting-started-with-wazuh

https://documentation.wazuh.com/current/getting-started/components/index.html#components

https://documentation.wazuh.com/current/getting-started/components/wazuh-indexer.html#wazuh-indexer

https://documentation.wazuh.com/current/getting-started/components/wazuh-server.html

https://documentation.wazuh.com/current/getting-started/components/wazuh-dashboard.html

https://documentation.wazuh.com/current/getting-started/components/wazuh-agent.html

https://documentation.wazuh.com/current/installation-guide/index.html

https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/index.html

https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/step-by-step.html

https://documentation.wazuh.com/current/installation-guide/wazuh-server/step-by-step.html

https://documentation.wazuh.com/current/installation-guide/wazuh-dashboard/step-by-step.html

https://documentation.wazuh.com/current/installation-guide/wazuh-agent/wazuh-agent-package-linux.html

https://documentation.wazuh.com/current/installation-guide/wazuh-agent/wazuh-agent-package-windows.html

https://documentation.wazuh.com/current/installation-guide/wazuh-agent/wazuh-agent-package-macos.htm

https://documentation.wazuh.com/current/installation-guide/packages-list.html

https://documentation.wazuh.com/current/installation-guide/uninstalling-wazuh/central-components.html

https://documentation.wazuh.com/current/installation-guide/uninstalling-wazuh/agent.html

https://documentation.wazuh.com/current/user-manual/index.html

https://documentation.wazuh.com/current/user-manual/manager/index.html

https://documentation.wazuh.com/current/user-manual/api/index.html

https://documentation.wazuh.com/current/user-manual/wazuh-indexer/index.html

https://documentation.wazuh.com/current/user-manual/indexer-api/index.html

https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/index.html

https://documentation.wazuh.com/current/user-manual/agent/index.html

https://documentation.wazuh.com/current/user-manual/ruleset/index.html

https://documentation.wazuh.com/current/upgrade-guide/index.html


Ansible Best Practices: https://docs.ansible.com
https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#con-gs-automation-execution

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#inventories

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#con-gs-automation-content

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#ansible_roles

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#ansible_playbooks

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#con-gs-automation-decisions

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#con-gs-automation-mesh

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#con-gs-ansible-lightspeed

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#con-gs-developer-tools

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#ref-gs-install-config

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#con-gs-dashboard-components

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-key-functionality#con-gs-final-set-up

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#setting-up-dev-env_assembly-gs-auto-dev

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#con-gs-create-automation-content

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#create_a_playbook

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#con-gs-define-events-rulebooks

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#rulebook_actions

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#con-gs-ansible-roles_assembly-gs-auto-dev

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#creating-ansible-role_assembly-gs-auto-dev

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#proc-gs-publish-to-a-collection_assembly-gs-auto-dev

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#con-gs-execution-env_assembly-gs-auto-dev

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#proc-gs-use-base-execution-env_assembly-gs-auto-dev

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#proc-gs-add-ee-to-job-template_assembly-gs-auto-dev

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#con-gs-build-decision-env

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#proc-gs-auto-dev-create-automation-decision-proj

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-dev#browsing_and_creating_inventories

https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/getting_started_with_ansible_automation_platform/assembly-gs-auto-op


