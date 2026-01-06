#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}!!! DESTROYING ENTIRE CLUSTER (Apps + Infra) !!!${NC}"
echo "Waiting 3 seconds... Press Ctrl+C to cancel."
sleep 3

kubectl delete namespace iot-system

echo -e "${RED}=== Cluster destroyed. ===${NC}"