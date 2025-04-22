# DevOps Challenge – Kubernetes Environment with Jenkins, PostgreSQL, Grafana, and Traefik

This setup provides a full DevOps stack running locally with Minikube. It includes:
- Jenkins with dynamic Kubernetes agents
- PostgreSQL as the database
- Grafana and Prometheus for monitoring
- Traefik as the ingress controller

---

## Prerequisites

Before getting started, make sure the following tools are installed:
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

3. Update your `/etc/hosts` file:
```
127.0.0.1 jenkins.local grafana.local prometheus.local
```

4. In a separate terminal, run:
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

Credentials for local development/testing are stored in `credentials.txt`:

| Service     | Username | Password         |
|-------------|----------|------------------|
| Jenkins     | admin    | auto-generated   |
| PostgreSQL  | postgres | auto-generated   |
| Grafana     | admin    | admin            |

---

## Uninstallation

To remove everything:
```bash
./deployment.sh uninstall
```

---

## Architecture Overview

This project deploys:
- Jenkins with dynamic agents using the Kubernetes plugin
- PostgreSQL with persistent storage
- Grafana and Prometheus for metrics and dashboards
- Traefik as a LoadBalancer Ingress to route traffic to services

---

## Future Improvements

- Add resource limits and readiness/liveness probes
- Integrate with GitHub Actions or use Jenkinsfiles for CI/CD pipelines
- Extend observability with custom Grafana dashboards

---

## Notes

This setup shows how to use infrastructure as code, container orchestration, and monitoring within a local Kubernetes cluster using Minikube.

