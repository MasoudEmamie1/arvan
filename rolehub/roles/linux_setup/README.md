# Observability_Setup — Documentation Suite

This repository contains ready‑to‑edit documentation templates install observability service for Grafana and Prometheus stack.

---

## README.md

```markdown
# Observability

Install and deploy a Prometheus and grafana and filebeat to send logs auth,kernel,sys to elasticsearch

## Supported Platforms

- Debian 12 / 11

## Requirements
- Ansible >= 2.13 (or your minimum)
- Python on managed hosts (e.g., Python 3.8+)
- Network access to:
  - ansible_port: 9510
  - ansible_user: root

## Role Variables

> Defaults live in `defaults/main.yml`. Required vars are marked **required**.

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `DOMAIN` | `need to add` | Define main domain services | **Yes** |
| `service_dir` | `need to add` | Define Project/service directiry | **Yes** |
| `project_dir` | `need to add` | Define Project directiry | **Yes** |
| `prometheus_image_tag` | `need to add` | Define image tag  | **Yes**|
| `filebeat_image_tag` | `need to add` | Define image tag | **Yes** |
| `grafana_image_tag` | `need to add` | Define image tag | **Yes** |
| `restart_policy` | `need to add` | Define container restart policy | **Yes** |
| `PROM_SUBDOMAIN_` | `need to add` | Define service subdomain| **Yes** |
| `GRAFANA_SUBDOMAIN_` | `need to add` |Define service subdomain | No |
| `HOSTNAME` | `need to add` | Define service hostname | No |
| `service_subdirs` | `need to add` | Define services sundirectory name | **Yes** |
| `service_dir_mode` | `need to add` | Define services sundirectory permission mode | **Yes** |

### vault Variables
```yaml
GRAFANA_USERNAME_MASKED
GRAFANA_PASSWORD_MASKED
WEB_AUTH_PROM_USER_MASKED
WEB_AUTH_PROM_PASS_MASKED
WEB_AUTH_PROM_PASS_MASKED_SCRAPE
```

## Dependencies
  - linux_setup
  - docker_setup
  - traefik_setup

## Tags
- `pull_observe` — package repos and packages
- `docker` — Docker prepare
- `directories ` —  Directories
- `config_files` — Config files
- `compose` — Compose files
- `deploy` — deploy service

## Examples

### Minimal
```yaml
- hosts: app
  roles:
    - role: observability-setuo
      vars:
        DOMAIN: xxx.yyy.zzz
        GRAFANA_PASSWORD_MASKED: "{{ vault_GRAFANA }}"
```


### Inventory

```yaml
all:
  vars:
    ansible_user: debian
    ansible_port: 9510
  children:
    arvan:
      hosts:
        observability-arvan:
        elk-arvan:
        S3-arvan:
```

## Handlers
- `restart containerd` — triggered when templates change
- `restart docker` — if supported


## Author
Masoud Emami (jalinuxy)
```

```
## Tasks (`tasks/main.yml`)
High‑level outline (do not duplicate full code):
1. Prepare server and install requirments.
2. Deploy desired service



## Tags
- `pull_observe`, `deploy`

## Supported Platforms (from `meta/main.yml`)
```yaml
galaxy_info:
  platforms:
    - name: Debian
      versions: ["bookworm", "bullseye"]

```

---

### Using tags
```bash
ansible-playbook site.yml --tags <tag-name>
ansible-playbook site.yml --skip-tags <tag-name>
```


## Folder Structure (example)

```text
observability_setup/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   └── preparing.yml
│   └── deploy.yml
├── templates/
│   └── prometheus.yml.j2
├── files/
│   └── compose.yml
│   └── pip.conf
└── README.md
```
