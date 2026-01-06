#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Starting ===${NC}"

kubectl create namespace iot-system --dry-run=client -o yaml | kubectl apply -f -

echo "Applying ConfigMap..."
kubectl apply -f k8s/configmap.yaml

echo "Ensuring Kafka Cluster is up..."
kubectl apply -f k8s/kafka-cluster.yaml

echo "Deploying Applications..."
kubectl apply -f k8s/bridge.yaml
kubectl apply -f k8s/consumer.yaml
kubectl apply -f k8s/generator.yaml

echo -e "${GREEN}Waiting for pods to be ready...${NC}"
kubectl wait --namespace iot-system \
  --for=condition=ready pod \
  --selector=app=bridge \
  --timeout=90s

echo -e "${GREEN}=== System is UP and RUNNING! ===${NC}"
echo "Use 'kubectl get pods -n iot-system' to check status."