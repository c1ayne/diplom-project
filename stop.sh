#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}=== Stopping Applications... ===${NC}"

kubectl delete -f k8s/bridge.yaml
kubectl delete -f k8s/consumer.yaml
kubectl delete -f k8s/generator.yaml

echo -e "${RED}=== Applications stopped. Infrastructure (Kafka/EMQX) is still running. ===${NC}"