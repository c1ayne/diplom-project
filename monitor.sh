#!/bin/bash
# monitor.sh — Развертывание мониторинга из локальных файлов

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}=== Развертывание мониторинга ===${NC}"

echo -e "${YELLOW}1. Prometheus + Grafana...${NC}"
helm upgrade --install my-monitoring k8s/install/helm-charts/kube-prometheus-stack-69.2.0.tgz \
    --namespace iot-system \
    --set prometheus-node-exporter.enabled=false \
    --set kubeStateMetrics.enabled=false \
    --set alertmanager.enabled=false \
    --wait

echo -e "${YELLOW}2. ServiceMonitor...${NC}"
kubectl apply -f k8s/monitoring/services.yaml
kubectl apply -f k8s/monitoring/servicemonitor.yaml

echo -e "${YELLOW}3. Пароль Grafana...${NC}"
GF_PASSWORD=$(kubectl get secret --namespace iot-system my-monitoring-grafana \
    -o jsonpath="{.data.admin-password}" | base64 --decode)

echo -e "${GREEN}=== Мониторинг готов! ===${NC}"
echo -e "${CYAN}URL    : http://localhost:3000${NC}"
echo -e "${CYAN}Логин  : admin${NC}"
echo -e "${CYAN}Пароль : ${GF_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}Запусти в отдельном терминале:${NC}"
echo "kubectl port-forward svc/my-monitoring-grafana 3000:80 -n iot-system"