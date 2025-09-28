## Ansible-Managed ELK Stack for Centralized Logging
### 1. Introduction
This document provides a comprehensive overview of the automated ELK stack deployment project. The goal of this project is to provide a simple, repeatable, and automated method for deploying a centralized logging solution.

The stack consists of a single-node Elasticsearch and Kibana instance running in Docker, provisioned by Ansible. Client servers are configured with Filebeat to collect system logs and forward them to the central Elasticsearch instance. The system is designed for easy management, log separation, and automated data retention using Index Lifecycle Management (ILM).


### 2. Architecture
The architecture consists of three main components: an ELK Server, and one or more Log Source Nodes.

ELK Server: A dedicated server that runs Elasticsearch and Kibana inside Docker containers. It receives, stores, and indexes all logs.

Log Source Nodes: Any server that needs to be monitored. These nodes run a Filebeat agent (here is prometheus server) to collect and forward logs to the ELK Server.

#### Architectural Diagram

The data flows from the Log Source Nodes to the ELK Server, where it is processed and made available for visualization in Kibana.

Filebeat on client servers tails log files (/var/log/syslog, /var/log/auth.log, /var/log/kern.log.).

Filebeat enriches the logs with metadata (e.g., log_type: "{auth,syslog,kern}") and sends them to Elasticsearch.

An Ingest Pipeline in Elasticsearch intercepts the data, reads the log_type field, and routes the log to the correct index (e.g., {auth,syslog,kern}-logs).

The index is automatically managed by an ILM Policy, which handles data retention.

Kibana connects to Elasticsearch, allowing users to search, visualize, and create dashboards from the log data.


### 3. Prerequisites
Control Node
Ansible (ansible-core >= 2.12)

Ansible Docker Collection: ansible-galaxy collection install community.docker

Target Nodes
OS: Debian

SSH Access: Key-based SSH access from the control node to all target nodes with a user that has sudo privileges.

Python: A modern version of Python (3.x) must be installed.

ELK Server Only: Docker and Docker Compose must be installed. The playbook includes a task to install these.

### 4. Repository Structure
The project is organized using standard Ansible roles for clear separation of concerns.
```
/
├── inventory/hosts.ini             
├── roles/
│   ├── elk_server/      
│
└── Playbooks/     
        └── elk.yml
```

### 5. Deployment
  ```bash
  ansible-playbook playbook/elk.yml -i inventory/hosts.yml --limit elk-prov 
  ```

### 6. Configuration
[ELK Deploy Readme](../../../rolehub/roles/elk_single_setup/README.md)
