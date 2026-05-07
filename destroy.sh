#!/bin/bash
# destroy.sh — Полное удаление стенда
# По умолчанию удаляет только namespace iot-system.
# С флагом --delete-cluster удаляет также kind-кластер и локальный registry.
#
# Использование:
#   ./destroy.sh                    # удалить только namespace
#   ./destroy.sh --delete-cluster   # удалить namespace + кластер + registry

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DELETE_CLUSTER=false
[ "$1" = "--delete-cluster" ] && DELETE_CLUSTER=true

if $DELETE_CLUSTER; then
    echo -e "${RED}!!! ПОЛНОЕ УДАЛЕНИЕ: namespace + kind-кластер + registry !!!${NC}"
else
    echo -e "${RED}!!! УДАЛЕНИЕ NAMESPACE iot-system (кластер и registry сохраняются) !!!${NC}"
fi

echo -e "${YELLOW}Ctrl+C для отмены.${NC}"
for i in 5 4 3 2 1; do echo "$i..."; sleep 1; done

# --- Удаление namespace ---
kubectl delete namespace iot-system

echo -e "${YELLOW}Ожидание завершения удаления namespace...${NC}"
elapsed=0
while [ $elapsed -lt 60 ]; do
    kubectl get namespace iot-system &>/dev/null || break
    sleep 3; elapsed=$((elapsed + 3))
done

# --- Опциональное удаление кластера и registry ---
if $DELETE_CLUSTER; then
    echo -e "${YELLOW}Удаление kind-кластера...${NC}"
    kind delete cluster --name iot-cluster

    echo -e "${YELLOW}Удаление локального registry...${NC}"
    docker stop kind-registry 2>/dev/null
    docker rm   kind-registry 2>/dev/null
fi

echo -e "${GREEN}=== Стенд удалён. ===${NC}"