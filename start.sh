#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Starting ===${NC}"

kubectl create namespace iot-system --dry-run=client -o yaml | kubectl apply -f -

echo -e "${YELLOW}Deploying Infrastructure (EMQX & Kafka)...${NC}"

# EMQX
helm repo add emqx https://repos.emqx.io/charts
helm upgrade --install my-emqx emqx/emqx \
  --namespace iot-system \
  --set replicaCount=1 \
  --wait

# Strimzi Operator
helm repo add strimzi https://strimzi.io/charts/
helm upgrade --install strimzi-kafka strimzi/strimzi-kafka-operator \
  --namespace iot-system \
  --wait

# PostgreSQL HA
echo -e "${YELLOW}Deploying PostgreSQL HA...${NC}"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm upgrade --install my-db bitnami/postgresql \
  --namespace iot-system \
  -f k8s/postgres-values.yaml \
  --wait

echo -e "${YELLOW}Applying Configs & Kafka Cluster...${NC}"
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/kafka-cluster.yaml

echo "Waiting for Kafka to be ready (this may take a minute)..."
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n iot-system 2>/dev/null || echo "Kafka is starting..."

echo -e "${YELLOW}Deploying Microservices...${NC}"

# Bridge
helm upgrade --install bridge ./k8s/charts/app-chart \
  --namespace iot-system \
  --set image.repository=diplomat/bridge --set image.tag=k8s \
  --set replicaCount=2 \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2

# Consumer
helm upgrade --install consumer ./k8s/charts/app-chart \
  --namespace iot-system \
  --set image.repository=diplomat/consumer --set image.tag=k8s \
  --set replicaCount=2

# Generator
helm upgrade --install generator ./k8s/charts/app-chart \
  --namespace iot-system \
  --set image.repository=diplomat/generator --set image.tag=k8s \
  --set replicaCount=5

echo -e "${GREEN}=== ALL SYSTEMS GO! ===${NC}"