#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting deployment of the distributed logging system with Istio service mesh...${NC}"

# Directories
K8S_DIR="../practicum-main/k8s"
ISTIO_DIR="."

# Check if istioctl is installed
if ! command -v istioctl &> /dev/null; then
    echo -e "${RED}istioctl is not installed. Please install Istio first.${NC}"
    echo -e "${YELLOW}You can install istio by running:${NC}"
    echo -e "curl -L https://istio.io/downloadIstio | sh -"
    echo -e "cd istio-*"
    echo -e "export PATH=\$PWD/bin:\$PATH"
    exit 1
fi

echo -e "\n${GREEN}Installing Istio in the cluster...${NC}"
istioctl install --set profile=demo -y
if [ $? -ne 0 ]; then echo -e "${RED}Failed to install Istio.${NC}"; exit 1; fi

echo -e "\n${GREEN}Enabling automatic sidecar injection in default namespace...${NC}"
kubectl label namespace default istio-injection=enabled --overwrite
if [ $? -ne 0 ]; then echo -e "${RED}Failed to enable sidecar injection.${NC}"; exit 1; fi

# Apply Kubernetes resources
echo -e "\n${GREEN}Applying ConfigMap...${NC}"
kubectl apply -f "${K8S_DIR}/configmap.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply ConfigMap.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Application Deployment...${NC}"
kubectl apply -f "${K8S_DIR}/deployment.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply Deployment.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Application Service...${NC}"
kubectl apply -f "${K8S_DIR}/service.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply Service.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Log Agent DaemonSet...${NC}"
kubectl apply -f "${K8S_DIR}/log-agent-daemonset.yaml"
if [ $? -ne 0 ]; then echo -e "${RED}Failed to apply DaemonSet.${NC}"; exit 1; fi

echo -e "\n${GREEN}Applying Log Archiver CronJob...${NC}"
kubectl apply -f "${K8S_DIR}/cronjob.yaml"
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

echo -e "\n${GREEN}Deployment complete!${NC}"
echo -e "You can access the application through the Istio ingress gateway"
echo -e "Check the ingress gateway IP with: ${YELLOW}kubectl get svc istio-ingressgateway -n istio-system${NC}"
echo -e "Example: ${YELLOW}http://<GATEWAY_IP>/${NC}"
echo -e "Check log agent logs with: ${YELLOW}kubectl logs -l app=log-agent${NC}"
echo -e "Log archiving CronJob '${YELLOW}log-archiver${NC}' is scheduled."

exit 0 