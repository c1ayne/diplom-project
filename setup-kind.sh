#!/bin/bash
# setup-kind.sh — Создание kind-кластера с локальным Docker Registry
# Запускать ОДИН РАЗ перед первым start.sh
# Повторный запуск безопасен: существующие ресурсы не пересоздаются

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;37m'
CYAN='\033[0;36m'
NC='\033[0m'

REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"
CLUSTER_NAME="iot-cluster"

# --- Проверка зависимостей ---
for tool in kind kubectl helm docker; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}Не найден инструмент: $tool${NC}"
        exit 1
    fi
done

echo -e "${GREEN}=== Настройка kind-кластера с локальным registry ===${NC}"

# --- 1. Локальный Docker Registry ---
echo -e "${YELLOW}1. Локальный Docker Registry...${NC}"

if [ "$(docker inspect -f '{{.State.Running}}' "$REGISTRY_NAME" 2>/dev/null)" = "true" ]; then
    echo -e "${GRAY}   Registry уже запущен — пропуск${NC}"
else
    docker run -d \
        --restart=always \
        --name "$REGISTRY_NAME" \
        -p "${REGISTRY_PORT}:5000" \
        registry:2

    [ $? -ne 0 ] && echo -e "${RED}Ошибка запуска registry${NC}" && exit 1
    echo -e "${GRAY}   Registry запущен на localhost:$REGISTRY_PORT${NC}"
fi

# --- 2. Kind-кластер ---
echo -e "${YELLOW}2. Kind-кластер ($CLUSTER_NAME)...${NC}"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${GRAY}   Кластер уже существует — пропуск${NC}"
else
    kind create cluster \
        --name "$CLUSTER_NAME" \
        --config kind-config.yaml \
        --wait 120s

    [ $? -ne 0 ] && echo -e "${RED}Ошибка создания кластера${NC}" && exit 1
    echo -e "${GRAY}   Кластер создан: 1 control-plane + 2 workers${NC}"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

# --- 3. Подключение registry к сети kind ---
echo -e "${YELLOW}3. Подключение registry к сети kind...${NC}"

if docker network inspect kind --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -q "$REGISTRY_NAME"; then
    echo -e "${GRAY}   Registry уже в сети kind — пропуск${NC}"
else
    docker network connect kind "$REGISTRY_NAME" 2>/dev/null
    echo -e "${GRAY}   Registry подключён к сети kind${NC}"
fi

# --- 4. ConfigMap для автоматического обнаружения registry нодами ---
echo -e "${YELLOW}4. Регистрация registry в кластере...${NC}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# --- Итог ---
echo -e "${GREEN}=== Кластер готов! ===${NC}"
echo ""
echo -e "${CYAN}Ноды кластера:${NC}"
kubectl get nodes
echo ""
echo -e "${CYAN}Registry: localhost:$REGISTRY_PORT${NC}"
echo -e "${CYAN}Контекст: kind-$CLUSTER_NAME${NC}"
echo ""
echo -e "${YELLOW}Следующий шаг: запусти start.sh${NC}"