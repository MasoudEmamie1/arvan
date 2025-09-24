# TODOs and Setup Instructions

## MySQL Replication Setup

On master of user creatation:
```sql
CREATE USER 'replication'@'%' IDENTIFIED BY 'arvan-replica';
ALTER USER 'replication'@'%' IDENTIFIED BY 'arvan-replica';
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'%';
```

On slave for Replication:
```sql
CHANGE MASTER TO
  MASTER_HOST='mysql-master-svc', ----> Best practice is to bootstrap from manifest
  MASTER_USER='replication',
  MASTER_PASSWORD='arvan-replica',
  MASTER_AUTO_POSITION = 1;
START REPLICA;
```

 ansible role for docker exec and provision
in filebeat for use default file beat dashboard:                         
```bash 
  filebeat setup --index-management --pipelines --dashboards -e \
  -E output.elasticsearch.hosts=["http://elasticsearch:9200"] \
  -E output.elasticsearch.username=elastic \
  -E output.elasticsearch.password='lh7e3n3GJ2TVso3WWlXc0IOSZOJ39HlWwCu4gYK8LwYd3emUZE' \
  -E setup.kibana.host=http://kibana:5601 \
  -E setup.kibana.username=elastic \
  -E setup.kibana.password='lh7e3n3GJ2TVso3WWlXc0IOSZOJ39HlWwCu4gYK8LwYd3emUZE'
```

ansible role for get_url and http request
use this in ansible for create a ilm policy:
```bash
curl -u '{{ ELASTIC_USERNAME_MASKED }}:{{ ELASTIC_PASSWORD_MASKED }}' -X PUT https://{{ SUBDOMAIN_ELASTIC }}.{{ DOMAIN }}:443/_ilm/policy/syslog_policy_ilm -H 'Content-Type: application/json' -d '{
  "policy": {
    "phases": {
      "hot":   { "actions": { "rollover": { "max_size": "10gb", "max_age": "1d" } } },
      "warm":  { "min_age": "3d", "actions": { "forcemerge": { "max_num_segments": 1 }, "shrink": { "number_of_shards": 1 } } },
      "delete":{ "min_age": "14d", "actions": { "delete": {} } }
    }
  }
}'
```

or one by one like:
```bash
-PUT _ilm/policy/logs-30d-policy
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "5gb",
            "max_age": "7d"
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": { "delete": {} }
      }
    }
  }
}
```
ansible role for get_url and http request
use this in ansible to create log template by ilm:
####for each {auth,kernel,sys}
```bash
curl -X PUT http://es.elk.kube0.ir/_index_template/syslog_template -H 'Content-Type: application/json' -d '{
  "index_patterns": ["syslog-*"],
  "template": {
    "settings": {
      "index.lifecycle.name": "syslog_policy_ilm",
      "index.lifecycle.rollover_alias": "syslog-write",
      "number_of_shards": 1, "number_of_replicas": 1
    },
    "mappings": { "properties": { "@timestamp": { "type": "date" } } }
  },
  "priority": 200
}'
```

ansible role for get_url and http request
use this for alias:
for each {auth,kernel,sys}
```bash
curl -X PUT http://<ELASTIC_IP>:9200/syslog-000001 -H 'Content-Type: application/json' -d '{
  "aliases": { "syslog-write": { "is_write_index": true } }
}'