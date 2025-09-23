# Task 2: Publish mysqld-exporter via Ingress (Basic Auth)

Expose the mysqld-exporter endpoints through an NGINX Ingress with basic auth and path-based routing:

`https://<host>/master/metrics → master Service (9104)`

`https://<host>/slave/metrics → replica Service (9104)`

## 0) Prereqs

- Ingress controller: ingressClassName: nginx present

- Services from Task 1/metrics step expose port 9104 and have correct selectors

- Secret: mysql-metrics-auth with a valid htpasswd line in data.auth

Generate `auth`:
``bash
# in Debian
```bash
sudo apt-get install apache2-utils
htpasswd -nbB admin 'YourStrongPass' | base64 -w0  #wrap encoded lines after COLS  character and Use 0 to disable line wrapping
```
secret-exporter.yml:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-metrics-auth
  namespace: arvan-test
type: Opaque
data:
  auth: <base64-of-htpasswd-line>
```
and apply :
```bash
kubectl -n arvan-test apply -f secret-exporter.yml
```

## 1) Ingress manifest:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mysql-metrics-ingress
  namespace: arvan-test
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: mysql-metrics-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: metrics.kube0.ir # <-- Your public domain
    http:
      paths:
      # Rule for the Master
      - path: /master(/|$)(.*)
        pathType: ImplementationSpecific # <-- CORRECTED
        backend:
          service:
            name: mysql-master-svc
            port:
              number: 9104
      # Rule for the Slave
      - path: /slave(/|$)(.*)
        pathType: ImplementationSpecific # <-- CORRECTED
        backend:
          service:
            name: mysql-slave-svc
            port:
              number: 9104
```

apply: 
```bash
kubectl -n arvan-test apply -f ingress.yml
```

## 2) Test
```bash
curl -u admin:YourStrongPass https://metrics.kube0.ir/master/metrics -k | head
curl -u admin:YourStrongPass https://metrics.kube0.ir/slave/metrics  -k | head
```

## 3) Troubleshooting

- 401 loop: Ensure the secret name/namespace match and auth is a valid htpasswd line.

- 404: Verify rewrite-target and path regex, Service name/port, and selectors.

- TLS: -k ignores TLS issues. For real TLS, configure certs on the Ingress.

- No metrics: Check exporter pod logs and that port 9104 is exposed and reachable.


## 4) Deliverables (ingress)

`kubectl -n arvan-test get ingress`

`curl output from both /master/metrics and /slave/metrics`
