#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Deploying Observability Stack===${NC}"

echo -e "${YELLOW}1. Adding Helm Repos...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo -e "${YELLOW}2. Installing kube-prometheus-stack...${NC}"
helm upgrade --install my-monitoring prometheus-community/kube-prometheus-stack \
  --namespace iot-system \
  --set prometheus-node-exporter.enabled=false \
  --set kubeStateMetrics.enabled=false \
  --set alertmanager.enabled=false \
  --wait

echo -e "${YELLOW}3. Configuring Service Discovery...${NC}"
kubectl apply -f k8s/monitoring/services.yaml
kubectl apply -f k8s/monitoring/servicemonitor.yaml

echo -e "${YELLOW}4. Getting Grafana credentials...${NC}"
GF_PASSWORD=$(kubectl get secret --namespace iot-system my-monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

echo -e "${GREEN}=== Monitoring Ready! ===${NC}"
echo -e "Grafana URL: http://localhost:3000"
echo -e "User:        admin"
echo -e "Password:    ${GF_PASSWORD}"
echo ""
echo -e "${YELLOW}To access Grafana, run this command in a separate terminal:${NC}"
echo "kubectl port-forward svc/my-monitoring-grafana 3000:80 -n iot-system"