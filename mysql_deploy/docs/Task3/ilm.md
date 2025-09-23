# ILM Policy (hot→warm→delete)
Define an ILM policy to rollover indices in the hot phase and then transition to warm and finally delete.

## 1) Example ILM policy
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
and then:
```http
GET _ilm/policy/logs-hot-warm-delete
```
