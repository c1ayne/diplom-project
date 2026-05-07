#!/bin/bash
# stop.sh — Остановка микросервисов (инфраструктура остаётся работать)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}=== Остановка микросервисов... ===${NC}"
helm uninstall bridge    -n iot-system
helm uninstall consumer  -n iot-system
helm uninstall generator -n iot-system
echo -e "${GREEN}=== Готово. Инфраструктура (Kafka/EMQX/PostgreSQL) работает. ===${NC}"