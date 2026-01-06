#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}=== Stopping Microservices... ===${NC}"

helm uninstall bridge -n iot-system
helm uninstall consumer -n iot-system
helm uninstall generator -n iot-system

echo -e "${RED}=== Apps stopped. Infrastructure (Kafka/EMQX) is still running. ===${NC}"