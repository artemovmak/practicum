#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting deployment of the distributed logging system with Istio service mesh and Prometheus monitoring...${NC}"

# Directories
K8S_DIR="k8s"
ISTIO_DIR="../practicum-2"
CURR_DIR=$(pwd)

# Check for necessary tools
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v istioctl &> /dev/null; then
    echo -e "${RED}istioctl is not installed. Please install Istio first.${NC}"
    echo -e "${YELLOW}You can install istio by running:${NC}"
    echo -e "curl -L https://istio.io/downloadIstio | sh -"
    echo -e "cd istio-*"
    echo -e "export PATH=\$PWD/bin:\$PATH"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}helm is not installed. Please install Helm first.${NC}"
    echo -e "${YELLOW}You can install helm by running:${NC}"
    echo -e "curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash"
    exit 1
fi

# Build and push the custom application image
echo -e "\n${GREEN}Building the custom application Docker image...${NC}"
cd app
docker build -t custom-app:v2 .
if [ $? -ne 0 ]; then echo -e "${RED}Failed to build Docker image.${NC}"; exit 1; fi
cd $CURR_DIR

# Install Istio if not already installed
echo -e "\n${GREEN}Installing Istio in the cluster...${NC}"
istioctl install --set profile=demo -y
if [ $? -ne 0 ]; then echo -e "${RED}Failed to install Istio.${NC}"; exit 1; fi

echo -e "\n${GREEN}Enabling automatic sidecar injection in default namespace...${NC}"
kubectl label namespace default istio-injection=enabled --overwrite
if [ $? -ne 0 ]; then echo -e "${RED}Failed to enable sidecar injection.${NC}"; exit 1; fi

# Install Prometheus Operator via Helm
echo -e "\n${GREEN}Adding Prometheus Helm repository...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
if [ $? -ne 0 ]; then echo -e "${RED}Failed to add Prometheus Helm repository.${NC}"; exit 1; fi

echo -e "\n${GREEN}Installing Prometheus Operator with custom values...${NC}"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values prometheus-values.yaml
if [ $? -ne 0 ]; then echo -e "${RED}Failed to install Prometheus.${NC}"; exit 1; fi

# Apply Kubernetes resources
echo -e "\n${GREEN}Applying ConfigMap...${NC}"
kubectl apply -f "../practicum-main/k8s/configmap.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply ConfigMap.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Application Deployment...${NC}"
kubectl apply -f "${K8S_DIR}/deployment.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply Deployment.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Application Service...${NC}"
kubectl apply -f "${K8S_DIR}/service.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply Service.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying ServiceMonitor...${NC}"
kubectl apply -f "${K8S_DIR}/service-monitor.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply ServiceMonitor.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Log Agent DaemonSet...${NC}"
kubectl apply -f "../practicum-main/k8s/log-agent-daemonset.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply DaemonSet.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Log Archiver CronJob...${NC}"
kubectl apply -f "../practicum-main/k8s/cronjob.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply CronJob.${NC}"; exit 1; fi

# Apply Istio resources
echo -e "\n${GREEN}Applying Istio Gateway...${NC}"
kubectl apply -f "${ISTIO_DIR}/gateway.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply Gateway.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Istio VirtualService...${NC}"
kubectl apply -f "${ISTIO_DIR}/virtualservice.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply VirtualService.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Istio DestinationRules...${NC}"
kubectl apply -f "${ISTIO_DIR}/destinationrule.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply DestinationRule.${NC}"; exit 1; fi

kubectl apply -f "${ISTIO_DIR}/log-destinationrule.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply Log DestinationRule.${NC}"; exit 1; fi

echo -e "\n${YELLOW}Waiting for Deployment rollout to complete...${NC}"
kubectl rollout status deployment/custom-app-deployment --timeout=120s
if [ $? -ne 0 ]; then echo -e "${RED}Deployment rollout failed or timed out.${NC}"; exit 1; fi

echo -e "\n${YELLOW}Waiting for DaemonSet rollout to complete...${NC}"
kubectl rollout status daemonset/log-agent --timeout=120s
if [ $? -ne 0 ]; then echo -e "${RED}DaemonSet rollout failed or timed out.${NC}"; exit 1; fi

# Wait for Prometheus to be ready
echo -e "\n${YELLOW}Waiting for Prometheus deployment to complete...${NC}"
kubectl rollout status deployment/prometheus-kube-prometheus-operator --namespace monitoring --timeout=180s
if [ $? -ne 0 ]; then echo -e "${RED}Prometheus deployment rollout failed or timed out.${NC}"; exit 1; fi

kubectl rollout status statefulset/prometheus-prometheus-kube-prometheus-prometheus --namespace monitoring --timeout=180s
if [ $? -ne 0 ]; then echo -e "${RED}Prometheus statefulset rollout failed or timed out.${NC}"; exit 1; fi

echo -e "\n${GREEN}Deployment complete!${NC}"
echo -e "You can access the application through the Istio ingress gateway"
echo -e "Check the ingress gateway IP with: ${YELLOW}kubectl get svc istio-ingressgateway -n istio-system${NC}"
echo -e "Example: ${YELLOW}http://<GATEWAY_IP>/${NC}"

echo -e "\nAccess Prometheus dashboard:"
echo -e "${YELLOW}kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090${NC}"
echo -e "Then open ${YELLOW}http://localhost:9090${NC} in your browser"

echo -e "\nAccess Grafana dashboard:"
echo -e "${YELLOW}kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80${NC}"
echo -e "Then open ${YELLOW}http://localhost:3000${NC} in your browser"
echo -e "Grafana credentials: admin / admin"

exit 0 