# MySQL Primary/Replica (Task 1: Deploy)

## Overview
- Namespace: `arvan-test`
- Topology: 1× master, 1× replica
- Image: `mysql:8.0`
- Storage: via `volumeClaimTemplates` in StatefulSets (PVCs are auto-created and Bound)
- Services: single Service per role exposing both 3306 (DB) and 9104 (metrics)
  
  > *In production, you usually separate DB and metrics Services; here we keep your combined Services.*

## 1) Prereqs
Create the namespace (if not already present):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: arvan-test #<namespace_name>
```


## 1) Secrets (database)
- `mysql-secret` contains root/replication/app passwords (base64-encoded).

    > Replace base64 values as needed.
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  # echo -n 'arvan' | base64   ||  openssl rand -base64 30 || 
  ROOT_PASSWORD: YXJ2YW4=
  # echo -n 'arvan-replica' | base64
  REPLICATION_PASSWORD: YXJ2YW4tcmVwbGljYQ== # Replication User
  ROOT_PASS_REP: YXJ2YW4y 
  APP_USER_PASSWORD: YXJ2YW4y # test user pass
```
as a `sample_secret.yml`
#### apply:
```bash
kubectl -n arvan-test apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: arvan-test
type: Opaque
data:
  ROOT_PASSWORD: YXJ2YW4=
  REPLICATION_PASSWORD: YXJ2YW4tcmVwbGljYQ==
  ROOT_PASS_REP: YXJ2YW4y
  APP_USER_PASSWORD: YXJ2YW4y
YAML
```
or
```bash
kubectl -n <namespace_name> appply -f <sample_secret.yml>
```

## 2) Configmaps (Tunning and Replication)
  - Contains master.cnf and slave.cnf. This profile favors benchmarking (higher TPS, lower durability).
  
    > remeber to seperate configs master and slave in real projects

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: arvan-test
data:
  master.cnf: |
    [mysqld]
    server_id=1
    log_bin=mysql-bin
    binlog_format=ROW
    default_authentication_plugin=mysql_native_password
    gtid_mode=ON
    enforce-gtid-consistency=ON
    local_infile=ON

    # --- Tuning Config for Master---
    innodb_buffer_pool_size=2600M
    innodb_buffer_pool_instances=2
    innodb_log_file_size=512M
    innodb_flush_method=O_DIRECT
    innodb_flush_neighbors=0
    innodb_io_capacity=2000
    innodb_io_capacity_max=4000
    innodb_read_io_threads=4
    innodb_write_io_threads=4
    tmp_table_size=128M
    max_heap_table_size=128M
    table_open_cache=4000
    table_open_cache_instances=8
    thread_cache_size=64
    max_connections=200
    open_files_limit=65535
    innodb_flush_log_at_trx_commit=2
    sync_binlog=0
  slave.cnf: |
    [mysqld]
    server_id=2
    log_bin=mysql-bin
    binlog_format=ROW
    gtid_mode=ON
    enforce-gtid-consistency=ON
    read_only=ON
    super_read_only=ON
    default_authentication_plugin=mysql_native_password

    # --- Tuning Config for Slave ---
    innodb_buffer_pool_size=2600M
    innodb_buffer_pool_instances=2
    innodb_log_file_size=512M
    innodb_flush_method=O_DIRECT
    innodb_flush_neighbors=0
    innodb_io_capacity=2000
    innodb_io_capacity_max=4000
    innodb_read_io_threads=4
    innodb_write_io_threads=4
    tmp_table_size=128M
    max_heap_table_size=128M
    table_open_cache=4000
    table_open_cache_instances=8
    thread_cache_size=64
    max_connections=200
    open_files_limit=65535
    local_infile=ON

```

#### apply: 
```bash
kubectl -n <namespace_name> appply -f <sample_config.yml>
```

## 3) Services (combined DB + metrics)
 - In production, you usually separate DB and metrics Services; here we keep your combined Services.
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-master-svc
  namespace: arvan-test
spec:
  ports:
    - name: mysql
      port: 3306
    - name: mysql-exporter
      port: 9104
      targetPort: 9104
  selector:
    app: mysql-master
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-slave-svc
  namespace: arvan-test
spec:
  ports:
    - name: mysql
      port: 3306
    - name: mysql-exporter
      port: 9104
      targetPort: 9104
  selector:
    app: mysql-slave
```

## 4) StatefulSets

##### 4.1) Master (with exporter bootstrap + exporter sidecar)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-master
  namespace: arvan-test
spec:
  selector:
    matchLabels:
      app: mysql-master
  serviceName: mysql-master-svc
  replicas: 1
  template:
    metadata:
      labels:
        app: mysql-master
        component: mysql-exporter
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '9104'
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
          name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: ROOT_PASSWORD
        - name: APP_USER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: APP_USER_PASSWORD
        - name: EXPORTER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-exporter-secret
              key: EXPORTER_PASSWORD
        resources:
          requests:
            cpu: "2"  # read some were to user 1.5 3.5 requests
            memory: "4Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
        - name: config-volume
          mountPath: /etc/mysql/conf.d
      - name: exporter-bootstrap
        image: mysql:8.0
        command: [ "sh", "-lc" ]
        args:
        - |
          echo "Waiting for MySQL to be ready...";
          sleep 10;
          until mysqladmin -hlocalhost -uroot -p"$MYSQL_ROOT_PASSWORD"; do sleep 2; done
          echo "Creating/Granting exporter user...";
          mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<'SQL'
          DROP USER IF EXISTS 'mysqld_exporter'@'127.0.0.1';
          DROP USER IF EXISTS 'mysqld_exporter'@'::1';       
          DROP USER IF EXISTS 'mysqld_exporter'@'localhost';
          CREATE USER IF NOT EXISTS 'mysqld_exporter'@'localhost' IDENTIFIED BY '${EXPORTER_PASSWORD}';
          CREATE USER IF NOT EXISTS 'mysqld_exporter'@'::1' IDENTIFIED BY '${EXPORTER_PASSWORD}'; # define this to prevent access issue
          CREATE USER IF NOT EXISTS 'mysqld_exporter'@'127.0.0.1' IDENTIFIED BY '${EXPORTER_PASSWORD}';
          GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'127.0.0.1';
          GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'::1';
          GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'localhost';
          FLUSH PRIVILEGES;
          SQL
          echo "Done. Exiting bootstrap container."
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: ROOT_PASSWORD
        - name: EXPORTER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-exporter-secret
              key: EXPORTER_PASSWORD
      - name: mysqld-exporter  # define as sidecar
        image: prom/mysqld-exporter:v0.14.0
        command: [ "/bin/sh", "-c" ]
        args:   # we can decide what metrics we need https://github.com/prometheus/mysqld_exporter
        - |
          set -e 
          export DATA_SOURCE_NAME="mysqld_exporter:${EXPORTER_PASSWORD}@tcp(127.0.0.1:3306)/"
          exec /bin/mysqld_exporter \                          
          --collect.global_status \                             
          --collect.info_schema.innodb_metrics \
          --collect.auto_increment.columns \
          --collect.info_schema.processlist \
          --collect.binlog_size \
          --collect.info_schema.tablestats \                    
          --collect.global_variables \
          --collect.info_schema.query_response_time \
          --collect.info_schema.userstats \
          --collect.info_schema.tables \
          --collect.perf_schema.tablelocks \
          --collect.perf_schema.file_events \
          --collect.perf_schema.eventswaits \
          --collect.perf_schema.indexiowaits \
          --collect.perf_schema.tableiowaits \
          --collect.slave_status
        ports:
        - containerPort: 9104
          name: exporter
        env:
        - name: EXPORTER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-exporter-secret
              key: EXPORTER_PASSWORD
        - name: DATA_SOURCE_NAME
          value: "mysqld_exporter:${EXPORTER_PASSWORD}@tcp(127.0.0.1:3306)/"
      volumes:
      - name: config-volume
        configMap:
          name: mysql-config
          items:
          - key: master.cnf
            path: master.cnf
  volumeClaimTemplates:                            # we use a sts so we use volumeclaimtemplate that create and bound pvc auto but we add some pvc manifest here for manually 
  - metadata:
      name: mysql-persistent-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 20Gi
```

pvc manifest:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-master-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```
##### 4.2) Slave (with exporter bootstrap + exporter sidecar)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-slave
  namespace: arvan-test
spec:
  selector:
    matchLabels:
      app: mysql-slave
  serviceName: mysql-slave-svc
  replicas: 1
  template:
    metadata:
      labels:
        app: mysql-slave
        component: mysql-exporter
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '9104'
    spec:
      initContainers:
      - name: wait-for-master
        image: busybox:1.28    # we need to master get up.
        command: [ 'sh', '-c', 'until nslookup mysql-master-svc; do echo waiting for master; sleep 2; done;' ]
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
          name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: ROOT_PASSWORD
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
        - name: config-volume
          mountPath: /etc/mysql/conf.d
      - name: mysqld-exporter
        image: prom/mysqld-exporter:v0.14.0
        args:
        - "--collect.global_status"
        - "--collect.info_schema.innodb_metrics"
        - "--collect.auto_increment.columns"
        - "--collect.info_schema.processlist"
        - "--collect.binlog_size"
        - "--collect.info_schema.tablestats"
        - "--collect.global_variables"
        - "--collect.info_schema.query_response_time"
        - "--collect.info_schema.userstats"
        - "--collect.info_schema.tables"
        - "--collect.perf_schema.tablelocks"
        - "--collect.perf_schema.file_events"
        - "--collect.perf_schema.eventswaits"
        - "--collect.perf_schema.indexiowaits"
        - "--collect.perf_schema.tableiowaits"
        - "--collect.slave_status"
        ports:
        - containerPort: 9104
          name: exporter
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: ROOT_PASSWORD
        - name: DATA_SOURCE_NAME
          value: "mysqld_exporter:${EXPORTER_PASSWORD}@tcp(127.0.0.1:3306)" #"root:$(MYSQL_ROOT_PASSWORD)@tcp(127.0.0.1:3306)/" if dont define and use mysql_exporter user here but bad security issue.
      volumes:
      - name: config-volume
        configMap:
          name: mysql-config
          items:
          - key: slave.cnf
            path: slave.cnf
  volumeClaimTemplates:
  - metadata:
      name: mysql-persistent-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 20Gi
```
Pvc Slave manifest:
```yaml
apiVersion: v1  # if need to manually create it
kind: PersistentVolumeClaim
metadata:
  name: mysql-slave-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

#### apply:
```bash
# if need to manually create pvc 
kubectl -n <namespace_name> apply -f mysql-master-pvc.yml
kubectl -n <namespace_name> apply -f mysql-slave-pvc.yml  
kubectl -n <namespace_name> apply -f mysql-master.yml 
kubectl -n <namespace_name> apply -f mysql-slave.yml
```

## 5) Configure replication
<!-- We can define this bootstraping beside other boot straping part in manifest deploy but want to show how to do  manually -->
If your bootstrap already sets it up, you can skip. Otherwise:
```bash

# Create replicator on master
kubectl -n arvan-test exec -it sts/mysql-master -- /bin/bash -lc '
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
CREATE USER 'replication'@'%' IDENTIFIED BY 'arvan-replica';
ALTER USER 'replication'@'%' IDENTIFIED BY 'arvan-replica';
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'%';
FLUSH PRIVILEGES;
"'

kubectl -n arvan-test exec -it sts/mysql-slave -- /bin/bash -lc '
mysql -e "
CHANGE MASTER TO
  MASTER_HOST='mysql-master-svc',
  MASTER_USER='replication',
  MASTER_PASSWORD='arvan-replica',
  MASTER_AUTO_POSITION = 1;
START REPLICA;
"'
```
we need to temp disable super_read_only here:
```sql
SET GLOBAL super_read_only = OFF;
```
and user native password for root or mysqld_exporter 
```sql
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY 'your_root_password';
CREATE USER IF NOT EXISTS 'mysqld_exporter'@'::1' IDENTIFIED WITH 'mysql_native_password' BY  'exporter';
CREATE USER IF NOT EXISTS 'mysqld_exporter'@'127.0.0.1' IDENTIFIED WITH 'mysql_native_password' BY  'exporter';
CREATE USER IF NOT EXISTS 'mysqld_exporter'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY  'exporter';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'::1';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'127.0.0.1';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'localhost';
SET GLOBAL super_read_only = ON;
FLUSH PRIVILEGES;

```

`tip` 
in spec we can disable in sysctl pod all ipv6
```yaml
spec:
  securityContext:
    sysctls:
    - name: net.ipv6.conf.all.disable_ipv6
      value: "1"
    - name: net.ipv6.conf.default.disable_ipv6
      value: "1"
  containers:
  - name: mysql
```
again turn off.
```sql
SET GLOBAL super_read_only = ON;
FLUSH PRIVILEGES;
EXIT;
```
## 6) Data generation
this source get a sample cvs from s3 and user from local to impoert csv data in db.
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: mysql-csv-load
  namespace: arvan-test
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      volumes:
        - name: data
          emptyDir: {}
      initContainers:
        - name: get-csv
          image: minio/mc:latest
          envFrom:
            - secretRef: { name: s3-auth }
          command: ["/bin/sh","-c"]
          args:
            - |
              set -euo pipefail
              mc alias set arvan "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_ACCESS_KEY" --insecure
              mc ls "$S3_BUCKET" --insecure
              mc cp "arvan/$S3_BUCKET_CSV/$S3_CSV_FILENAME" /data/$S3_CSV_FILENAME --insecure
              ls -lh /data
          volumeMounts:
            - name: data
              mountPath: /data
      containers:
        - name: load-to-mysql
          image: bitnami/mysql:latest
          env:
            - name: MYSQL_HOST
              value: "mysql-master-svc"
            - name: MYSQL_USER
              value: "root"
            - name: MYSQL_PWD
              valueFrom: { secretKeyRef: { name: mysql-secret, key: ROOT_PASSWORD } }
            - name: CSV_PATH
              value: "/data/employees.csv"             
          command: ["/bin/bash","-lc"]
          args:
            - |
              set -euo pipefail
              : "${CSV_PATH:?missing}"
              test -s "$CSV_PATH" || { echo "CSV not found: $CSV_PATH"; exit 1; }
              sed -i 's/\r$//' "$CSV_PATH" || true
              /opt/bitnami/mysql/bin/mysql -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PWD" -e "SHOW GLOBAL VARIABLES LIKE 'local_infile';"
              cat <<SQL | /opt/bitnami/mysql/bin/mysql --local-infile=1 -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PWD"
              CREATE DATABASE IF NOT EXISTS demo;
              USE demo;
              CREATE TABLE IF NOT EXISTS events(
                id BIGINT PRIMARY KEY,
                user_id BIGINT,
                event_type VARCHAR(32),
                created_at DATETIME
              ) ENGINE=InnoDB;
              LOAD DATA LOCAL INFILE '$CSV_PATH'
              INTO TABLE events
              FIELDS TERMINATED BY ',' ENCLOSED BY '"'
              LINES TERMINATED BY '\n'
              IGNORE 1 LINES
              (id, user_id, event_type, @ts)
              SET created_at = STR_TO_DATE(@ts, '%Y-%m-%d %H:%i:%s');
              SQL
          volumeMounts:
            - name: data
              mountPath: /data
```

```bash
kubectl -n arvan-test apply -f date_generate.yml
```
## 7) Validate
```bash
kubectl -n arvan-test get pods,svc
```

#### Master: GTID + status
```bash
kubectl -n arvan-test exec -it sts/mysql-master-0 -- \
  mysql -uroot -p$(kubectl -n arvan-test get secret mysql-secret -o jsonpath='{.data.ROOT_PASSWORD}' | base64 -d) \
  -e "SHOW VARIABLES LIKE 'gtid_mode'; SHOW MASTER STATUS;"
```

#### Replica: replication status
```bash
kubectl -n arvan-test exec -it sts/mysql-slave-0 -- \
  mysql -uroot -p$(kubectl -n arvan-test get secret mysql-secret -o jsonpath='{.data.ROOT_PASSWORD}' | base64 -d) \
  -e "SHOW REPLICA STATUS\G"
```  
##### Expect: Replica_IO_Running=Yes, Replica_SQL_Running=Yes, Seconds_Behind_Source ≈ 0

## 7) Notes

- PVCs are auto-created via volumeClaimTemplates—no manual PVC needed unless pre-provisioning.

- Exporter user on replica is replicated from master; to avoid race/lag, we use a wait loop.

- Tuning values favor benchmarking (see innodb_flush_log_at_trx_commit=2 and sync_binlog=0).
For production durability, prefer 1 and 1.