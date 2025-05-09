#!/bin/bash

set -e

# colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' 
 

# check if required tools are installed
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # check minikube
    if ! command -v minikube &> /dev/null; then
        echo -e "${YELLOW}Minikube not found. Installing...${NC}"
        brew install minikube || { echo -e "${RED}Failed to install Minikube.${NC}"; exit 1; }
    fi
    
    # check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}kubectl not found. Installing...${NC}"
        brew install kubectl || { echo -e "${RED}Failed to install kubectl.${NC}"; exit 1; }
    fi

    # check helm
    if ! command -v helm &> /dev/null; then
        echo -e "${YELLOW}Helm not found. Installing...${NC}"
        brew install helm || { echo -e "${RED}Failed to install Helm.${NC}"; exit 1; }
    fi

    # check docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found. Installing...${NC}"
        brew install --cask docker || { echo -e "${RED}Failed to install Docker.${NC}"; exit 1; }
        echo -e "${YELLOW}Please open Docker Desktop manually after installation.${NC}"
    fi

    # check terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${YELLOW}Terraform not found. Installing...${NC}"
        brew tap hashicorp/tap
        brew install hashicorp/tap/terraform || { echo -e "${RED}Failed to install Terraform.${NC}"; exit 1; }
    fi

    echo -e "${GREEN}✔ All prerequisites are installed.${NC}"
}

# TODO: move traefik before other services

# start Docker
start_docker() {
  echo -e "${YELLOW}Starting Docker...${NC}"
  open -a Docker

  echo -e "${YELLOW}Waiting for Docker to be ready...${NC}"
  while ! docker system info > /dev/null 2>&1; do
    sleep 2
  done

  echo -e "${GREEN}Docker is running!${NC}"
}


# start minikube
start_minikube() {
    echo -e "${YELLOW}Starting Minikube...${NC}"
    
    # check if minikube is already running
    if minikube status | grep -q "Running"; then
        echo -e "${GREEN}Minikube is already running.${NC}"
    else
        echo -e "${YELLOW}Starting Minikube with 4 CPUs, 6GB RAM, and 20GB disk...${NC}"
        minikube start --cpus=4 --memory=6144 --disk-size=20g
        
        # enable ingress addon for Traefik
        echo -e "${YELLOW}Enabling ingress addon...${NC}"
        minikube addons enable ingress
    fi
    
    # set docker env to use minikube's docker daemon
    echo -e "${YELLOW}Setting docker environment to minikube...${NC}"
    eval $(minikube docker-env)
    
    echo -e "${GREEN}Minikube is ready.${NC}"
}

# Prompt user to start minikube tunnel
prompt_minikube_tunnel() {
    echo -e "${RED}Please start 'minikube tunnel' in a separate terminal and press Enter when done...${NC}"
    echo -e "${RED}Don't forget to use the right minikube context by entering 'minikube update-context' ${NC}"
    echo -e "${GREEN}Continuing with the script...${NC}"ß
}

# Create Kubernetes secrets
create_secrets() {
    echo -e "${YELLOW}Creating Kubernetes secrets...${NC}"
    
    # Generate random passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 12)
    JENKINS_ADMIN_PASSWORD=$(openssl rand -base64 12)
    
    # Create secrets
    kubectl create secret generic postgres-secret \
        --from-literal=postgres-password=${POSTGRES_PASSWORD} \
        --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl create secret generic jenkins-secret \
        --from-literal=jenkins-admin-password=${JENKINS_ADMIN_PASSWORD} \
        --from-literal=jenkins-admin-user=admin \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}Secrets created successfully.${NC}"
    echo -e "${YELLOW}PostgreSQL Password: ${POSTGRES_PASSWORD}${NC}"
    echo -e "${YELLOW}Jenkins Admin Password: ${JENKINS_ADMIN_PASSWORD}${NC}"
    
    # Save credentials to a file with restricted permissions
    echo "PostgreSQL Password: ${POSTGRES_PASSWORD}" > ./credentials.txt
    echo "Jenkins Admin Password: ${JENKINS_ADMIN_PASSWORD}" >> ./credentials.txt
    
    # Set restrictive permissions (only owner can read/write)
    chmod 600 ./credentials.txt
    
    echo -e "${GREEN}Credentials saved to ./credentials.txt with restricted permissions${NC}"
}

# Deploy PostgreSQL using Helm
deploy_postgres() {
    echo -e "${YELLOW}Deploying PostgreSQL...${NC}"
    
    # Add bitnami repo if not already added
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo update
    
    helm upgrade --install  postgres bitnami/postgresql \
          --set global.storageClass=standard \
          --set global.postgresql.auth.username=myuser \
          --set global.postgresql.auth.password=mypassword \
          --set global.postgresql.auth.database=mydatabase \
          --set primary.persistence.size=5Gi \
          --set volumePermissions.enabled=true

    # Wait for PostgreSQL to be ready
    echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=300s
    
    echo -e "${GREEN}PostgreSQL deployed successfully.${NC}"
}

# Deploy Prometheus using Helm
deploy_prometheus() {
    echo -e "${YELLOW}Deploying Prometheus...${NC}"
    
    # Add prometheus repo if not already added
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update
    
#     # Create a ConfigMap for Prometheus scrape config
#     cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: prometheus-postgres-scrape-config
# data:
#   postgres-scrape.yaml: |-
#     - job_name: 'postgres-metrics'
#       kubernetes_sd_configs:
#         - role: pod
#       relabel_configs:
#         - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
#           action: keep
#           regex: postgresql
#         - source_labels: [__meta_kubernetes_pod_container_port_number]
#           action: keep
#           regex: 9187
#         - source_labels: [__meta_kubernetes_namespace]
#           target_label: kubernetes_namespace
#         - source_labels: [__meta_kubernetes_pod_name]
#           target_label: kubernetes_pod_name
# EOF
    
    # Deploy Prometheus with LoadBalancer service type
    echo -e "${YELLOW}Deploying Prometheus with LoadBalancer service...${NC}"
    helm upgrade --install prometheus prometheus-community/prometheus \
        --set server.service.type=LoadBalancer \
        --set server.service.servicePort=9090 \
        --set server.global.scrape_interval=15s \
        --set server.global.evaluation_interval=15s \
        --set server.persistentVolume.size=4Gi \
        # --set configmapReload.prometheus.enabled=true \
        # --set server.extraConfigmapMounts[0].name=prometheus-postgres-scrape-config \
        # --set server.extraConfigmapMounts[0].mountPath=/etc/prometheus/postgres-scrape.yaml \
        # --set server.extraConfigmapMounts[0].subPath=postgres-scrape.yaml \
        # --set server.extraConfigmapMounts[0].configMap=prometheus-postgres-scrape-config \
        # --set server.extraConfigmapMounts[0].readOnly=true \
        # --set-string server.additionalScrapeConfigs[0]="\$(cat /etc/prometheus/postgres-scrape.yaml)"
    
    # Wait for Prometheus to be ready
    echo -e "${YELLOW}Waiting for Prometheus to be ready...${NC}"
    sleep 10
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server --timeout=300s || true
    
    echo -e "${GREEN}Prometheus deployed successfully.${NC}"
}

# deploy jenkins
deploy_jenkins() {
    echo -e "${YELLOW}Deploying Jenkins...${NC}"
    
    # Add jenkins repo if not already added
    helm repo add jenkins https://charts.jenkins.io 2>/dev/null || true
    helm repo update
    
    # Clean up any previous failed deployments
    echo -e "${YELLOW}Cleaning up any previous Jenkins deployments...${NC}"
    helm uninstall jenkins || true
    kubectl delete pvc jenkins-pvc || true
    kubectl delete configmap jenkins-casc-config || true
    kubectl delete -f jenkins-config.yaml || true
    
    # Deploy Jenkins using the values file
    echo -e "${YELLOW}Deploying Jenkins with non-root configuration...${NC}"
    # helm install jenkins jenkins/jenkins --values jenkins-values.yaml
    helm install jenkins jenkins/jenkins \
    --set controller.serviceType=LoadBalancer \
    --set controller.admin.username=admin \
    --set controller.admin.password=admin123 \
    --set persistence.enabled=true \
    --set persistence.size=5Gi
    
    # Wait for Jenkins to be ready
    echo -e "${YELLOW}Waiting for Jenkins to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller --timeout=600s || true
    
    echo -e "${GREEN}Jenkins deployed successfully.${NC}"
    
    # If Jenkins is still not ready, provide debug information
    if ! kubectl get pods -l app.kubernetes.io/component=jenkins-controller | grep -q "Running"; then
        echo -e "${RED}Jenkins pod is not running. Checking pod status:${NC}"
        kubectl get pods -l app.kubernetes.io/component=jenkins-controller
        echo -e "${RED}Jenkins pod events:${NC}"
        kubectl describe pod -l app.kubernetes.io/component=jenkins-controller
    fi
}

# deploy traefik
deploy_traefik() {
    echo -e "${YELLOW}Deploying Traefik...${NC}"
    
    helm repo add traefik https://helm.traefik.io/traefik 2>/dev/null || true
    helm repo update
    
    kubectl delete ingressroute --all 2>/dev/null || true
    kubectl delete middleware --all 2>/dev/null || true
    kubectl delete ingress --all 2>/dev/null || true
    
    helm uninstall traefik 2>/dev/null || true
    
    # echo -e "${YELLOW}Installing Traefik CRDs...${NC}"
    # kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml || true
    
    echo -e "${YELLOW}Installing Traefik ...${NC}"
    helm install traefik traefik/traefik \
      --set ingress.enabled=true
    
    echo -e "${YELLOW}Waiting for Traefik to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traefik --timeout=300s || true
    
    # echo -e "${YELLOW}Verifying Traefik CRDs...${NC}"
    # if ! kubectl get crd | grep -q ingressroutes.traefik.containo.us; then
    #     echo -e "${RED}Traefik CRDs not found. Installing manually...${NC}"
    #     TEMP_DIR=$(mktemp -d)
    #     curl -s https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml > "${TEMP_DIR}/traefik-crds.yml"
    #     kubectl apply -f "${TEMP_DIR}/traefik-crds.yml"
    #     echo -e "${YELLOW}Waiting for manually installed CRDs to register...${NC}"
    #     sleep 15
    #     rm -rf "${TEMP_DIR}"
    # fi
    
    # if ! kubectl get crd | grep -q ingressroutes.traefik.containo.us; then
    #     echo -e "${RED}Warning: Traefik CRDs still not found. IngressRoutes may not work.${NC}"
    # else
    #     echo -e "${GREEN}Traefik CRDs verified successfully.${NC}"
    # fi
    
    echo -e "${GREEN}Traefik deployed successfully.${NC}"
}

# Deploy Grafana using Helm
deploy_grafana() {
    echo -e "${YELLOW}Deploying Grafana...${NC}"
    
    # Add grafana repo if not already added
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo update
    
    # Deploy Grafana with LoadBalancer service type
helm upgrade --install grafana grafana/grafana \
    --set service.type=LoadBalancer \
    --set service.port=3000 \
    --set persistence.enabled=true \
    --set persistence.size=1Gi \
    --set adminPassword=admin \
    --set datasources."datasources\.yaml".apiVersion=1 \
    --set datasources."datasources\.yaml".datasources[0].name=PostgreSQL \
    --set datasources."datasources\.yaml".datasources[0].type=postgres \
    --set datasources."datasources\.yaml".datasources[0].url="postgres-postgresql:5432" \
    --set datasources."datasources\.yaml".datasources[0].user="myuser" \
    --set datasources."datasources\.yaml".datasources[0].database="mydatabase" \
    --set datasources."datasources\.yaml".datasources[0].access="proxy" \
    --set datasources."datasources\.yaml".datasources[0].isDefault=true \
    --set datasources."datasources\.yaml".datasources[0].jsonData.sslmode="disable" \
    --set datasources."datasources\.yaml".datasources[0].secureJsonData.password="mypassword"
    
    # Wait for Grafana to be ready
    echo -e "${YELLOW}Waiting for Grafana to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s
    
    # Save current directory
    CURRENT_DIR=$(pwd)
    
    # Configure Grafana using Terraform - with improved directory handling
    echo -e "${YELLOW}Configuring Grafana with Terraform...${NC}"
    
    # Create terraform directory if it doesn't exist
    if [ ! -d "terraform" ]; then
        echo -e "${YELLOW}Creating terraform directory...${NC}"
        mkdir -p terraform
    fi
    
    # Change to terraform directory with absolute path
    echo -e "${YELLOW}Changing to terraform directory...${NC}"
    cd "${CURRENT_DIR}/terraform" || {
        echo -e "${RED}Failed to change to terraform directory. Skipping Terraform configuration.${NC}"
        return
    }
    
    # Initialize Terraform with better error handling
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init || {
        echo -e "${RED}Terraform initialization failed. Skipping Terraform configuration.${NC}"
        cd "${CURRENT_DIR}"
        return
    }
    
    # Wait for Grafana to be fully ready
    echo -e "${YELLOW}Waiting for Grafana API to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s
    sleep 10
    
    # Forward port to Grafana service for Terraform to connect
    echo -e "${YELLOW}Setting up port forwarding to Grafana...${NC}"
    kubectl port-forward svc/grafana 3000:3000 > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    # Apply Terraform configuration with better error handling
    echo -e "${YELLOW}Applying Terraform configuration...${NC}"
    TF_VAR_grafana_url="http://localhost:3000" terraform apply -auto-approve || {
        echo -e "${YELLOW}Terraform apply had non-zero exit code. This might be normal for an initial deployment.${NC}"
    }
    
    # Kill port forwarding
    if [ -n "$PORT_FORWARD_PID" ]; then
        echo -e "${YELLOW}Stopping port forwarding...${NC}"
        kill $PORT_FORWARD_PID || true
    fi
    
    # Return to original directory
    cd "${CURRENT_DIR}" || {
        echo -e "${RED}Failed to return to original directory. Script may behave unexpectedly.${NC}"
    }
    
    echo -e "${GREEN}Grafana configuration completed.${NC}"
}

# Create and apply all Kubernetes resources
apply_k8s_resources() {
    echo -e "${YELLOW}Applying Kubernetes resources...${NC}"
    
    # Apply Jenkins job
    echo -e "${YELLOW}Applying Jenkins job configuration...${NC}"
    kubectl apply -f jenkins-job.yaml || true
    
    echo -e "${GREEN}Kubernetes resources applied successfully.${NC}"
}

# Create ingress routes for services
apply_ingress_routes() {
    echo -e "${YELLOW}Applying ingress routes for services...${NC}"

    # Apply ingress route for Jenkins
    kubectl apply -f jenkins-ingress.yaml
    
    # Apply ingress route for Grafana
    kubectl apply -f grafana-ingress.yaml
    
    # Apply ingress route for Prometheus
    kubectl apply -f prometheus-ingress.yaml
    
    # Add local hosts entries
    echo -e "${YELLOW}Adding local hosts entries...${NC}"
    MINIKUBE_IP=$(minikube ip)
    
    echo -e "${YELLOW}Add the following entries to your /etc/hosts file:${NC}"
    HOST_IP="${MINIKUBE_IP}"
    
    echo -e "${YELLOW}Add the following entries to your /etc/hosts file:${NC}"
    echo -e "${YELLOW}${HOST_IP} jenkins.local grafana.local prometheus.local${NC}"
    
    # Optionally, you can automatically add to /etc/hosts if running with sudo
    if [ "$EUID" -eq 0 ]; then
        echo -e "${YELLOW}Adding entries to /etc/hosts automatically...${NC}"
        if ! grep -q "jenkins.local" /etc/hosts; then
            echo "${HOST_IP} jenkins.local grafana.local prometheus.local" >> /etc/hosts
        fi
    else
        echo -e "${RED}Please run the following command manually with sudo:${NC}"
        echo -e "${RED}sudo sh -c \"echo '${HOST_IP} jenkins.local grafana.local prometheus.local' >> /etc/hosts\"${NC}"
    fi
    echo -e "${GREEN}Ingress routes created successfully.${NC}"
}

# Display access information
display_access_info() {
    echo -e "${YELLOW}Getting service access information...${NC}"
    
    # Get Minikube IP
    MINIKUBE_IP=$(minikube ip)
    
    echo -e "${YELLOW}Important: To access LoadBalancer services, run 'minikube tunnel' in a separate terminal.${NC}"
    echo -e "${YELLOW}The tunnel command may require your administrator password.${NC}"
    echo -e "${YELLOW}Keep the tunnel running while you access the services.${NC}"
    echo -e "\n"
    
    # Wait for LoadBalancer IPs to be assigned
    echo -e "${YELLOW}Waiting for LoadBalancer IPs to be assigned...${NC}"
    sleep 10
    
    # Get LoadBalancer IPs
    JENKINS_IP=$(kubectl get svc jenkins -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    GRAFANA_IP=$(kubectl get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    PROMETHEUS_IP=$(kubectl get svc prometheus-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    TRAEFIK_IP=$(kubectl get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    echo -e "${GREEN}Access your services via LoadBalancer IPs:${NC}"
    
    if [ -n "$JENKINS_IP" ]; then
        echo -e "${GREEN}Jenkins: http://${JENKINS_IP}:8080${NC}"
    else
        echo -e "${YELLOW}Jenkins LoadBalancer IP not assigned yet.${NC}"
        echo -e "${GREEN}After running 'minikube tunnel', Jenkins will be available at: http://127.0.0.1:8080${NC}"
    fi
    
    if [ -n "$GRAFANA_IP" ]; then
        echo -e "${GREEN}Grafana: http://${GRAFANA_IP}:3000${NC}"
    else
        echo -e "${YELLOW}Grafana LoadBalancer IP not assigned yet.${NC}"
        echo -e "${GREEN}After running 'minikube tunnel', Grafana will be available at: http://127.0.0.1:3000${NC}"
    fi
    
    if [ -n "$PROMETHEUS_IP" ]; then
        echo -e "${GREEN}Prometheus: http://${PROMETHEUS_IP}:9090${NC}"
    else
        echo -e "${YELLOW}Prometheus LoadBalancer IP not assigned yet.${NC}"
        echo -e "${GREEN}After running 'minikube tunnel', Prometheus will be available at: http://127.0.0.1:9090${NC}"
    fi
    
    if [ -n "$TRAEFIK_IP" ]; then
        echo -e "${GREEN}Traefik Dashboard: http://${TRAEFIK_IP}:9000/dashboard/${NC}"
    else
        echo -e "${YELLOW}Traefik LoadBalancer IP not assigned yet.${NC}"
        echo -e "${GREEN}After running 'minikube tunnel', Traefik Dashboard will be available at: http://127.0.0.1:9000/dashboard/${NC}"
    fi
    
    echo -e "${GREEN}Or access via Ingress (after running 'minikube tunnel'):${NC}"
    echo -e "${GREEN}Jenkins: http://jenkins.local/${NC}"
    echo -e "${GREEN}Grafana: http://grafana.local/${NC}"
    echo -e "${GREEN}Prometheus: http://prometheus.local/${NC}"
    
    echo -e "${YELLOW}Jenkins Admin Credentials:${NC}"
    echo -e "${YELLOW}Username: admin${NC}"
    echo -e "${YELLOW}Password: $(kubectl get secret jenkins-secret -o jsonpath='{.data.jenkins-admin-password}' | base64 --decode)${NC}"
    
    echo -e "${YELLOW}Grafana Admin Credentials:${NC}"
    echo -e "${YELLOW}Username: admin${NC}"
    echo -e "${YELLOW}Password: admin${NC}"
    
    echo -e "${YELLOW}PostgreSQL Admin Credentials:${NC}"
    echo -e "${YELLOW}Username: postgres${NC}"
    echo -e "${YELLOW}Password: $(kubectl get secret postgres-secret -o jsonpath='{.data.postgres-password}' | base64 --decode)${NC}"
}

# Uninstall everything
uninstall() {
    echo -e "${YELLOW}Uninstalling all components...${NC}"
    
    # Kill any running minikube tunnel
    pkill -f "minikube tunnel" || true

    # Kill any port forwarding processes
    pkill -f "kubectl port-forward" || true
    
    # Delete all ingress resources first
    echo -e "${YELLOW}Removing ingress routes...${NC}"
    kubectl delete -f jenkins-ingress.yaml || true
    kubectl delete -f grafana-ingress.yaml || true
    kubectl delete -f prometheus-ingress.yaml || true
    
    kubectl delete ingressroute --all || true
    kubectl delete middleware --all || true
    kubectl delete ingress --all || true
    
    # Remove all Helm releases
    echo -e "${YELLOW}Removing Helm releases...${NC}"
    helm uninstall grafana || true
    helm uninstall traefik || true
    helm uninstall jenkins || true
    helm uninstall postgres || true
    helm uninstall prometheus || true
    
    # Delete all PVCs
    echo -e "${YELLOW}Removing persistent volume claims...${NC}"
    kubectl delete pvc --all || true
    
    # Delete all configmaps and secrets
    echo -e "${YELLOW}Removing configmaps and secrets...${NC}"
    kubectl delete configmap --all || true
    kubectl delete secret postgres-secret jenkins-secret || true
    
    echo -e "${GREEN}All components uninstalled successfully.${NC}"
    
    # Ask if Minikube should be stopped
    read -p "Do you want to stop Minikube? (y/n): " stop_minikube
    if [ "$stop_minikube" = "y" ]; then
        minikube stop
        echo -e "${GREEN}Minikube stopped.${NC}"
    fi
}

# Install all components
install() {
    start_docker
    check_prerequisites
    start_minikube
    prompt_minikube_tunnel
    create_secrets
    deploy_postgres
    deploy_jenkins
    deploy_prometheus
    deploy_traefik
    deploy_grafana
    apply_ingress_routes
    apply_k8s_resources
    display_access_info
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 install|uninstall"
    exit 1
fi

case "$1" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        echo "Usage: $0 install|uninstall"
        exit 1
esac

exit 0
