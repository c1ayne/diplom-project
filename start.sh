#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Starting High-Load IoT Platform (Helm Mode) ===${NC}"

echo -e "${YELLOW}1. Applying Configuration...${NC}"
kubectl create namespace iot-system --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml

kubectl delete deployment bridge consumer generator -n iot-system --ignore-not-found=true

echo -e "${YELLOW}2. Deploying Bridge Service (with HPA)...${NC}"
helm upgrade --install bridge ./k8s/charts/app-chart \
  --namespace iot-system \
  --set image.repository=diplomat/bridge \
  --set image.tag=k8s \
  --set replicaCount=2 \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10 \
  --set autoscaling.targetCPUUtilizationPercentage=70 \
  --set resources.requests.cpu=200m \
  --set resources.limits.cpu=500m

# 4. Запуск Consumer (HPA: min 2, max 10)
echo -e "${YELLOW}3. Deploying Consumer Service (with HPA)...${NC}"
helm upgrade --install consumer ./k8s/charts/app-chart \
  --namespace iot-system \
  --set image.repository=diplomat/consumer \
  --set image.tag=k8s \
  --set replicaCount=2 \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10 \
  --set resources.requests.cpu=200m

echo -e "${YELLOW}4. Deploying Generators (Fixed scale)...${NC}"
helm upgrade --install generator ./k8s/charts/app-chart \
  --namespace iot-system \
  --set image.repository=diplomat/generator \
  --set image.tag=k8s \
  --set replicaCount=5 \
  --set resources.requests.cpu=50m

echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo "Check status: kubectl get pods -n iot-system"
echo "Check HPA:    kubectl get hpa -n iot-system"