# docker_setup — Documentation Suite

This repository contains ready‑to‑edit documentation templates install Docker service for Grafana and Prometheus stack.

---

## README.md

```markdown
# Docker

Inspall and deploy a Docker in linux server located in Iran
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
| `docker_dependencies` | `yes` | Docker dependencies packages | **Yes** |
| `docker_packages` | `yes` | Docker Debian packages | **Yes** |
| `docker_repo` | `yes` | Define Mirror  | **Yes** |
| `docker_config` | `yes` | Set some docker deamon conf  | **Yes**|


```

## Dependencies
  - linux_setup

## Tags
- `docker_preparing` — package repos and packages
- `docker` — Docker prepare


### Minimal
```yaml
- hosts: app
  roles:
    - role: Docker-setup
      vars:
        ansible_port : xxx.yyy.zzz
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
        Docker-arvan:
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
1. docker preparing
2. docker installation
3. docker configuration



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
docker_setup/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── configuration.yml
│   ├── preparing.yml   
└── installation.yml
├── templates/
│   ├── apt 
│   │    └── docker-ce.list.j2
│   ├── docker
│         └── daemon.json.j2
└── README.md
```
