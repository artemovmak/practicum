#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting deployment of the distributed logging system...${NC}"

K8S_DIR="k8s"

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

echo -e "\n${YELLOW}Waiting for Deployment rollout to complete...${NC}"
kubectl rollout status deployment/custom-app-deployment --timeout=120s
if [ $? -ne 0 ]; then echo -e "${RED}Deployment rollout failed or timed out.${NC}"; exit 1; fi

echo -e "\n${YELLOW}Waiting for DaemonSet rollout to complete...${NC}"
kubectl rollout status daemonset/log-agent --timeout=120s
if [ $? -ne 0 ]; then echo -e "${RED}DaemonSet rollout failed or timed out.${NC}"; exit 1; fi

echo -e "\n${GREEN}Deployment complete!${NC}"
echo -e "You can test the application service at: ${YELLOW}http://custom-app-service/ ${NC}(within the cluster)"
echo -e "Check log agent logs with: ${YELLOW}kubectl logs -l app=log-agent${NC}"
echo -e "Log archiving CronJob '${YELLOW}log-archiver${NC}' is scheduled."

exit 0
