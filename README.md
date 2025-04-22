# DevOps Challenge – Kubernetes Environment with Jenkins, PostgreSQL, Grafana, and Traefik

This project sets up a full DevOps stack using Minikube. It includes:
- Jenkins with dynamic Kubernetes agents
- PostgreSQL as the database
- Grafana and Prometheus for monitoring
- Traefik as the ingress controller

---

## Prerequisites

Before running this project, make sure you have the following installed:
- Minikube
- kubectl
- Helm
- Docker
- Terraform

---

## Installation

1. Clone the repository:
```bash
git clone https://github.com/cx-or-carmeli/DevOps-Challenge-Or.git
cd DevOps-Challenge-Or
```

2. Run the deployment script:
```bash
./deployment.sh install
```

3. Add the following to your `/etc/hosts` file:
```
127.0.0.1 jenkins.local grafana.local prometheus.local
```

4. Start `minikube tunnel` in a separate terminal:
```bash
minikube tunnel
```

---

## Accessing the Services

| Service    | URL                   |
|------------|------------------------|
| Jenkins    | http://jenkins.local   |
| Grafana    | http://grafana.local   |
| Prometheus | http://prometheus.local|

---

## Credentials

Stored in `credentials.txt` (for development/testing only):

| Service     | Username | Password         |
|-------------|----------|------------------|
| Jenkins     | admin    | auto-generated   |
| PostgreSQL  | postgres | auto-generated   |
| Grafana     | admin    | admin            |

---

## Uninstallation

To remove all resources:
```bash
./deployment.sh uninstall
```

---

## Architecture Overview

This project deploys:

- Jenkins with Kubernetes plugin for dynamic agents
- PostgreSQL with persistent storage
- Grafana and Prometheus for dashboards and metrics
- Traefik as a LoadBalancer Ingress for routing to services

---

## Future Improvements

- Add resource limits and probes in manifests
- Integrate GitHub Actions or Jenkinsfile for CI/CD
- Improve observability with custom Grafana dashboards

---

## Notes

This project demonstrates infrastructure as code, container orchestration, and observability in a local Kubernetes cluster using Minikube.
