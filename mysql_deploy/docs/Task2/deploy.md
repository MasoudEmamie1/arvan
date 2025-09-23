## 0) Prereqs
- Namespace: `arvan-test`
- Task 1 deployed (master/replica running)
- Secrets:
  - `mysql-secret` (root password)
  - `mysql-exporter-secret` with `EXPORTER_PASSWORD`
- ConfigMap: `mysql-config` already mounted by StatefulSets

## 1) Exporter user strategy (choose ONE)
**A) Master-only (replication-aware)** — Create user on **master** only. On **replica**, exporter waits until user is present (replicated) before starting.

**B) Idempotent on both** — Run a minimal bootstrap on **both** nodes with `CREATE USER IF NOT EXISTS ...` and `GRANT ...`. Safe vs. timing and replication lag.

> For the challenge, A is fine. For production hardening, B is also acceptable.

## 2) Secret for exporter
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-exporter-secret
  namespace: arvan-test
type: Opaque
stringData:
  EXPORTER_PASSWORD: "exporter"
```
```bash
kubectl -n arvan-test apply -f secrets-exporter.yaml
```

## 3) Master: exporter bootstrap + exporter sidecar
Your StatefulSet adds a bootstrap container that creates/grants mysqld_exporter users and a sidecar that serves metrics on 9104.

```yaml
- name: exporter-bootstrap
  image: mysql:8.0
  command: [ "sh", "-lc" ]
  args: |
    for i in $(seq 1 60); do
      mysqladmin -h127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" ping >/dev/null 2>&1 && break
      sleep 2
    done
    mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
    DROP USER IF EXISTS 'mysqld_exporter'@'127.0.0.1';
    DROP USER IF EXISTS 'mysqld_exporter'@'::1';
    DROP USER IF EXISTS 'mysqld_exporter'@'localhost';
    CREATE USER IF NOT EXISTS 'mysqld_exporter'@'localhost'  IDENTIFIED BY '${EXPORTER_PASSWORD}';
    CREATE USER IF NOT EXISTS 'mysqld_exporter'@'::1'       IDENTIFIED BY '${EXPORTER_PASSWORD}';
    CREATE USER IF NOT EXISTS 'mysqld_exporter'@'127.0.0.1' IDENTIFIED BY '${EXPORTER_PASSWORD}';
    GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'localhost';
    GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'::1';
    GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'127.0.0.1';
    FLUSH PRIVILEGES;
    SQL

- name: mysqld-exporter
  image: prom/mysqld-exporter:v0.14.0
  command: [ "/bin/sh", "-c" ]
  args: |
    set -eu
    export DATA_SOURCE_NAME="mysqld_exporter:${EXPORTER_PASSWORD}@tcp(127.0.0.1:3306)/"
    exec /bin/mysqld_exporter --collect.global_status --collect.info_schema.innodb_metrics \
      --collect.auto_increment.columns --collect.info_schema.processlist --collect.binlog_size \
      --collect.info_schema.tablestats --collect.global_variables --collect.info_schema.query_response_time \
      --collect.info_schema.userstats --collect.info_schema.tables --collect.perf_schema.tablelocks \
      --collect.perf_schema.file_events --collect.perf_schema.eventswaits \
      --collect.perf_schema.indexiowaits --collect.perf_schema.tableiowaits --collect.slave_status
```

## 4) Replica: exporter with wait loop

Waits until the replicated user exists, then starts exporter.

```yaml
- name: mysqld-exporter
  image: prom/mysqld-exporter:v0.14.0
  command: [ "/bin/sh", "-c" ]
  args: |
    set -eu
    for i in $(seq 1 120); do
      mysql -h127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" -N \
        -e "SELECT 1 FROM mysql.user WHERE user='mysqld_exporter' LIMIT 1" | grep -q 1 && break
      echo "waiting for replicated exporter user..."; sleep 2
    done
    export DATA_SOURCE_NAME="mysqld_exporter:${EXPORTER_PASSWORD}@tcp(127.0.0.1:3306)/"
    exec /bin/mysqld_exporter --collect.global_status --collect.info_schema.innodb_metrics \
      --collect.auto_increment.columns --collect.info_schema.processlist --collect.binlog_size \
      --collect.info_schema.tablestats --collect.global_variables --collect.info_schema.query_response_time \
      --collect.info_schema.userstats --collect.info_schema.tables --collect.perf_schema.tablelocks \
      --collect.perf_schema.file_events --collect.perf_schema.eventswaits \
      --collect.perf_schema.indexiowaits --collect.perf_schema.tableiowaits --collect.slave_status
```

## 5) Services (port 9104 exposed)
We already expose 9104 together with 3306 per role.
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-master-svc
  namespace: arvan-test
spec:
  ports:
  - { name: mysql, port: 3306 }
  - { name: mysql-exporter, port: 9104, targetPort: 9104 }
  selector: { app: mysql-master }
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-slave-svc
  namespace: arvan-test
spec:
  ports:
  - { name: mysql, port: 3306 }
  - { name: mysql-exporter, port: 9104, targetPort: 9104 }
  selector: { app: mysql-slave }
```

## 6) Validate
```bash
kubectl -n arvan-test get pods,svc
kubectl -n arvan-test port-forward svc/mysql-master-svc 9104:9104 &
curl -s localhost:9104/metrics | head
```
