# Task 2: Publish mysqld-exporter via Ingress (Basic Auth)
## 0) Prereqs
  - setup linux server -> [Ansible Role](../../../rolehub/roles/linux_setup/README.md)
  - Install docker -> [Ansible Role](../../../rolehub/roles/docker_setup/README.md)
  - Install and config Traefik ->[Ansible Role](../../../rolehub/roles/traefik_setup/_setup/README.md)
  - 
## 1) ELK Deploy

ELK is delpoy by ansible role read for info :
[ELK Ansible readme](../../../rolehub/roles/elk_single_setup/README.md)

apply:
```bash 
# if not define in ansible.cfg
ansible-playbook -i <inventory> --limit <Host>
```


## 3) Verify cluster is green
```bash
curl https://<ELASTIC_DOMAIN>/_cat/health
```
Expected status:
  - yellow -> single node

## 4) Verify Filebeat integration
```bash
docker exec -it <filebeat_service_name> filebeat test output
```
and expected to get sth like:
```bash
elasticsearch: http://elasticsearch:9200...
  parse url... OK
  connection...
    parse host... OK
    dns lookup... OK
    addresses: 172.20.0.2
    dial up... OK
  TLS... WARN secure connection disabled
  talk to server... OK
  version: 7.17.13
```
