# ILM Policy (hot→warm→delete)
Define an ILM policy to rollover indices in the hot phase and then transition to warm and finally delete.

## 1) Example ILM policy
```json
PUT _ilm/policy/logs-hot-warm-delete
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": { "max_primary_shard_size": "50gb", "max_age": "1d" },
          "set_priority": { "priority": 100 }
        }
      },
      "warm": {
        "min_age": "2d",
        "actions": {
          "allocate": { "require": { "data": "warm" } },
          "forcemerge": { "max_num_segments": 1 },
          "set_priority": { "priority": 50 }
        }
      },
      "delete": {
        "min_age": "14d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```
and then:
```json
GET _ilm/policy/logs-hot-warm-delete
```