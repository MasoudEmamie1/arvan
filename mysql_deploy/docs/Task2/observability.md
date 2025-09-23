# Task 2: Publish mysqld-exporter via Ingress (Basic Auth)
## 0) Prereqs

- Prometheus reachable to scrape cluster pods.

- Grafana connected to the same Prometheus datasource.

- mysqld-exporter running and reachable on 9104.
## 0) Deploy 
```bash
ansible-playbook -i rolehub/playbooks/observability.yml
```
for more info use: 
[Observability Ansible Readme](../../../rolehub/roles/observability_setup/README.md)

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
 
![Prometheus Screenshot](https://private-user-images.githubusercontent.com/85158772/492824140-de1388f8-bd25-4fd0-b86b-6526473ff2c2.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTg2MzIxODIsIm5iZiI6MTc1ODYzMTg4MiwicGF0aCI6Ii84NTE1ODc3Mi80OTI4MjQxNDAtZGUxMzg4ZjgtYmQyNS00ZmQwLWI4NmItNjUyNjQ3M2ZmMmMyLmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MjMlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTIzVDEyNTEyMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTY1NDIwNmQ0YjIwOGI1ZjI3YTY4Zjg4NjEzMzkxOWQxMDAxNTM1MDI5OTM5ZGI3ZTY3ZmE3MzNmYzYxOGIyYWQmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.mbw3Uj32XLkJWAMvP6a-c1--PcVUwH4snHZFtZZwEkI)

- Grafana dashboard screenshot focusing on TPS, buffer pool, and replication lag

![Grafana Screenshot](https://private-user-images.githubusercontent.com/85158772/492827206-fd2466fa-6272-4927-9ea2-feb3365b2d44.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTg2MzI0MjIsIm5iZiI6MTc1ODYzMjEyMiwicGF0aCI6Ii84NTE1ODc3Mi80OTI4MjcyMDYtZmQyNDY2ZmEtNjI3Mi00OTI3LTllYTItZmViMzM2NWIyZDQ0LmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MjMlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTIzVDEyNTUyMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWQ4MDRhODI3NWU1MmI4M2RiMjQ2Yzc4MmE2ZGZmZTA1NWI0YzkxZWVlNzgwMTdkMmQwYzU1M2U4NTFlMGRhNGEmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.dA9B4utuEUqKetPTVrP7jxyAHg79fLBrdpPrnVUtlMM)
- A short note on which dashboard you used/imported
    > here for sample import dashboard url: https://grafana.com/grafana/dashboards/14057-mysql/ 

    > id 14057