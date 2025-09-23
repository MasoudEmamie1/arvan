# Task 1: MySQL Tuning Profile

A pragmatic tuning profile for a 4Gi/2vCPU pod targeting higher **TPS** and lower **p95 latency** for read-heavy and mixed workloads.

> **Heads-up:** The profile uses **reduced durability** during benchmarking:
> - `innodb_flush_log_at_trx_commit=2`
> - `sync_binlog=0`
> For production, prefer `1` and `1`.

---

## 1) Parameters (used in `mysql-config`)

| Parameter | Why |
|---|---|
| `innodb_buffer_pool_size=2600M` | ~65% of 4Gi; bigger cache → fewer disk reads |
| `innodb_buffer_pool_instances=2` | Reduce mutex contention in buffer pool |
| `innodb_log_file_size=512M` | Fewer checkpoints; better write bursts (longer crash recovery) |
| `innodb_flush_method=O_DIRECT` | Bypass OS page cache; stable IO (no double buffering) |
| `innodb_flush_neighbors=0` | SSD-friendly; reduce write amplification |
| `innodb_io_capacity=1000`, `innodb_io_capacity_max=2000` | Background flushing hints |
| `innodb_read_io_threads=2`, `innodb_write_io_threads=2` | Parallelism for IO |
| `tmp_table_size=128M`, `max_heap_table_size=128M` | Larger in-memory temporary tables |
| `table_open_cache=4000`, `table_open_cache_instances=8` | Avoid table open/close churn |
| `thread_cache_size=64` | Faster connection handling |
| `max_connections=200` | Upper bound for concurrency |
| `open_files_limit=65535` | Avoid file descriptor pressure |
| `innodb_flush_log_at_trx_commit=2` | Less fsync; more TPS (weaker durability) |
| `sync_binlog=0` | Binlog not fsync per txn (faster, less durable) |
| `local_infile=ON` | Allow `LOAD DATA LOCAL INFILE` for data loading jobs |
| `performance_schema=off` | turns off instrumentation to reduce overhead (but you lose performance metrics). |
| `interactive_timeout=300` | closes idle interactive client sessions after 300 seconds. |
| `wait_timeout = 300` | closes idle non-interactive client sessions after 300 seconds. |
| `sort_buffer_size = 2M` | per-connection memory used for sorts; bigger can speed large sorts but raises RAM per session. |
| `read_buffer_size = 2M` | per-connection buffer for sequential reads/table scans; larger can speed scans but costs RAM. |
| `slow_query_log=1` | enables logging of slow queries to help find bottlenecks. |
| `long_query_time=1` | logs any query taking ≥1 second as a slow query. |

---


## 2) Rollout the config safely

```bash
kubectl -n arvan-test apply -f configmap.yaml
kubectl -n arvan-test rollout restart statefulset/mysql-master
kubectl -n arvan-test rollout restart statefulset/mysql-slave
kubectl -n arvan-test rollout status statefulset/mysql-master
kubectl -n arvan-test rollout status statefulset/mysql-slave
```
## 3) Verify in MySQL
```sql
SHOW VARIABLES WHERE Variable_name IN
('innodb_buffer_pool_size','innodb_buffer_pool_instances','innodb_log_file_size',
 'innodb_flush_method','innodb_flush_neighbors','innodb_flush_log_at_trx_commit',
 'sync_binlog','innodb_io_capacity','innodb_io_capacity_max',
 'innodb_read_io_threads','innodb_write_io_threads',
 'tmp_table_size','max_heap_table_size','table_open_cache','table_open_cache_instances',
 'thread_cache_size','max_connections','open_files_limit','local_infile');
```

## 4) Production profile (quick note)
need strong durability by tuning:

- innodb_flush_log_at_trx_commit=1

- sync_binlog=1

- Re-evaluate IO/threading based on your storage SLA
