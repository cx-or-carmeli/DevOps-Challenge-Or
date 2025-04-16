# Minikube DevOps Environment

A simple script to set up a complete DevOps environment on Minikube with Jenkins, Prometheus, Grafana, PostgreSQL, and Traefik.

## Requirements

- Minikube
- kubectl
- Helm
- Docker
- Terraform

## Quick Start

1. Clone this repository
2. Run the setup script:
   ```bash
   ./deployment.sh install
   ```

3. Add hostname entries to your `/etc/hosts` file:
   ```bash
   # The script will show you the exact command to run
   sudo sh -c "echo '[MINIKUBE_IP] jenkins.local grafana.local prometheus.local' >> /etc/hosts"
   ```

4. Start Minikube tunnel in a separate terminal:
   ```bash
   minikube tunnel
   ```

## Accessing Services

- Jenkins: http://jenkins.local/
- Grafana: http://grafana.local/
- Prometheus: http://prometheus.local/

## Credentials

All credentials are saved in `credentials.txt` after installation.

Default credentials:
- Jenkins: admin / (generated password)
- Grafana: admin / admin
- PostgreSQL: postgres / (generated password)

## Uninstall

To remove everything:
```bash
./deployment.sh uninstall
```

## Troubleshooting

If Jenkins crashes, try running the install script again with the updated deployment configuration.

If services aren't accessible, check:
1. Minikube tunnel is running
2. Hosts file contains the correct entries
3. All pods are running: `kubectl get pods`
