# Create a user 'prometheus' and  password
htpasswd -c auth prometheus

# Create the Kubernetes secret from this file
kubectl create secret generic mysql-exporter-auth --from-file=auth -n sre-challenge


# Install certmanger
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
