#!/bin/bash

# Get minikube IP
MINIKUBE_IP=$(minikube ip)

echo "Opening service URLs in your default browser..."

# Function to open URL based on OS
open_url() {
    local url=$1
    
    case "$(uname -s)" in
        "Darwin")  # macOS
            open "$url"
            ;;
        "Linux")
            if command -v xdg-open > /dev/null; then
                xdg-open "$url"
            else
                echo "Cannot open browser automatically. Please visit: $url"
            fi
            ;;
        *)
            echo "Cannot open browser automatically. Please visit: $url"
            ;;
    esac
}

# Ask which service to open
echo "Which service would you like to open?"
echo "1. Jenkins"
echo "2. Grafana"
echo "3. Prometheus"
echo "4. Traefik"
echo "5. All of the above"
read -p "Enter your choice (1-5): " choice

case "$choice" in
    1) open_url "http://jenkins.${MINIKUBE_IP}.nip.io:30080" ;;
    2) open_url "http://grafana.${MINIKUBE_IP}.nip.io:30080" ;;
    3) open_url "http://prometheus.${MINIKUBE_IP}.nip.io:30080" ;;
    4) open_url "http://traefik.${MINIKUBE_IP}.nip.io:30080" ;;
    5)
        open_url "http://jenkins.${MINIKUBE_IP}.nip.io:30080"
        sleep 1
        open_url "http://grafana.${MINIKUBE_IP}.nip.io:30080"
        sleep 1
        open_url "http://prometheus.${MINIKUBE_IP}.nip.io:30080"
        sleep 1
        open_url "http://traefik.${MINIKUBE_IP}.nip.io:30080"
        ;;
    *) echo "Invalid choice. Please run the script again." ;;
esac
