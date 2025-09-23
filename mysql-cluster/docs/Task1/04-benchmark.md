# Task 1: Sysbench Before/After

Compare **TPS** and **p95 latency** before vs after tuning using Sysbench OLTP profiles.

---

## 1) How this job is structured

- **initContainer** (`prepare-sysbench`):  
  Installs sysbench, ensures DB exists, checks for existing `sbtest*` tables:  
  - If none → `prepare`  
  - If partial → `cleanup` then `prepare`
- **container** (`run-sysbench`):  
  Runs 3 test types with multiple thread counts for a fixed duration, parses results, and writes a **CSV**:

    | phase  | test              | threads | tps    | latency_p95_ms |
    |--------|-------------------|---------|--------|----------------|
    | before | oltp_point_select | 1       | 456.26 | 2.43           |


Optionally uploads CSV to S3 if benchmark creds are provided.


## 2) Run “before” (pre-tuning)

Set `PHASE=before` and ensure MySQL has the **pre-tune** config:

```bash
kubectl -n arvan-test apply -f job-sysbench.yaml
kubectl -n arvan-test logs job/mysql-sysbench -f
```
the CSV path from logs (e.g., /results/sysbench-before-YYYY-MM-DD-HHMMSS.csv).

## 3) Apply tuning

Follow 03-tuning.md (apply ConfigMap, restart master & replica). Wait until pods are Ready.

## 4) Run “after” (post-tuning)

Change the env to PHASE=after in job-sysbench.yaml, re-apply and watch logs:
```bash
kubectl -n arvan-test apply -f job-sysbench.yaml
kubectl -n arvan-test logs job/mysql-sysbench -f
```

## 5) What to report

Create a tiny table comparing delta TPS and delta p95 for each test & thread:

  | phase  | test              | threads | tps    | latency_p95_ms |
  |--------|-------------------|---------|--------|----------------|
  | before | oltp_point_select | 1       | 456.26 |     2.43       |
  | after  | oltp_point_select | 1       | 953.66 |     2.57       |

Interpretation cheatsheet:

TPS ↑ → higher throughput (good)

p95 ↓ → better tail latency (good)

Large gains on read_write are expected with benchmark durability (2/0)

## 6) Troubleshooting

“Table 'sbtestN' already exists” during prepare

Your job already handles mismatch: if table count differs, it runs cleanup then prepare.

If you want to force rebuild: set a flag/env to always run cleanup first.

“Loading local data is disabled”

Ensure local_infile=ON in your MySQL config and pass --local-infile=1 on the client when using LOAD DATA LOCAL INFILE (CSV loader job).

Auth / DNS errors

Confirm MYSQL_HOST=mysql-master-svc resolves (nslookup inside the pod).

Check mysql-secret is in the same namespace (arvan-test).

## 7) Optional: Upload results to S3

Provide benchmark-write creds in s3-auth (e.g., S3_ACCESS_KEY_ID_BENCHMARK_WRITE, S3_SECRET_ACCESS_KEY_BENCHMARK_WRITE) and set:
```yaml
env:
- name: S3_RESULTS
  value: "arvan-write/benchmark/benchmarks"
envFrom:
- secretRef: { name: s3-auth }
```
The job will mc cp the CSV to the path you specify.