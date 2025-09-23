# Task 2: Publish mysqld-exporter via Ingress (Basic Auth)
## 0) Prereqs

- Prometheus reachable to scrape cluster pods.

- Grafana connected to the same Prometheus datasource.

- mysqld-exporter running and reachable on 9104.

## 1) Prometheus scraping
- Scrape by annotations
    ```yaml
        ...
        prometheus.io/scrape: "true"
        prometheus.io/port: "9104"
        ...
    ```
Your StatefulSets already include these annotations.

## 2) Grafana dashboards

- Import a MySQL exporter dashboard (e.g., Percona MySQL Overview, community “MySQL Exporter”).

Key panels to include:

- Uptime / Current QPS
- InnoDB buffer pool
- MySQL Connections / MySQL Client Thread Activity
- MySQL Questions/ MySQL Thread Cache
- MySQL Temporary Objects / MySQL Select Types
- ...

## 3) Validate targets

- Prometheus UI → Targets → Confirm master & replica UP

- Explore metrics: mysql_global_status_threads, mysql_global_status_queries

- Grafana: panels populate without errors

## 4) Troubleshooting


- Metrics missing: Verify exporter that MySQL socket is reachable (127.0.0.1:3306).

- Lag panel empty: Ensure replica exporter runs and replication is configured; pick correct metric name.

- Permissions: Exporter user must have PROCESS, REPLICATION CLIENT, SELECT on *.*.

## 5) Deliverables (observability)

- Screenshot of Prometheus Targets page.
![Prometheus Screenshot](https://github.com/MasoudEmamie1/arvan-test/blob/master/prometheus.jpg)

- Grafana dashboard screenshot focusing on TPS, buffer pool, and replication lag
![Grafana Screenshot](https://github.com/MasoudEmamie1/arvan-test/blob/master/grafana.jpg)
- A short note on which dashboard you used/imported
    > here for sample import dashboard url: https://grafana.com/grafana/dashboards/14057-mysql/ 

    > id 14057