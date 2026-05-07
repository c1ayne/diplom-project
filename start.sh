#!/bin/bash
# start.sh — Развертывание стенда (kind + локальный registry)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;37m'
NC='\033[0m'

if ! command -v helm &>/dev/null; then
    echo -e "${RED}Helm не найден.${NC}"
    exit 1
fi

# Адрес локального registry
REGISTRY="localhost:5001"

echo -e "${GREEN}=== Запуск стенда ===${NC}"
kubectl create namespace iot-system --dry-run=client -o yaml | kubectl apply -f -

echo -e "${YELLOW}1. Strimzi Operator...${NC}"
sed 's/namespace: myproject/namespace: iot-system/g' \
    k8s/install/strimzi-cluster-operator-0.45.0.yaml | \
    kubectl apply -f - -n iot-system

echo -e "${YELLOW}Ожидание Strimzi...${NC}"
kubectl rollout status deployment/strimzi-cluster-operator -n iot-system --timeout=120s
[ $? -ne 0 ] && echo -e "${RED}Strimzi не запустился${NC}" && exit 1
sleep 15

echo -e "${YELLOW}2. EMQX...${NC}"
helm upgrade --install my-emqx k8s/install/helm-charts/emqx-5.8.9.tgz \
    --namespace iot-system \
    --set replicaCount=1 \
    --wait

echo -e "${YELLOW}3. PostgreSQL...${NC}"
helm upgrade --install my-db k8s/install/helm-charts/postgresql-18.6.2.tgz \
    --namespace iot-system \
    -f k8s/postgres-values.yaml \
    --wait

echo -e "${YELLOW}4. ConfigMap и Secret...${NC}"
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml

echo -e "${YELLOW}5. Kafka-кластер...${NC}"
kubectl apply -f k8s/kafka-cluster.yaml
echo -e "${YELLOW}Ожидание Kafka (3-5 минут)...${NC}"
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n iot-system
[ $? -ne 0 ] && echo -e "${RED}Kafka не готова${NC}" && exit 1

# --- Сборка и публикация образов в локальный registry ---
# В kind imagePullPolicy=Never не работает для образов не из registry.
# Все образы пушатся в локальный registry (localhost:5001),
# который смонтирован в каждую ноду кластера как kind-registry:5000
echo -e "${YELLOW}6. Сборка и публикация образов в локальный registry...${NC}"

declare -A SERVICES=(
    ["bridge"]="./bridge"
    ["consumer"]="./consumer-service"
    ["generator"]="./generator"
)

declare -A IMAGE_NAMES=(
    ["bridge"]="diplomat/bridge"
    ["consumer"]="diplomat/consumer"
    ["generator"]="diplomat/generator"
)

for svc in bridge consumer generator; do
    tag="$REGISTRY/${IMAGE_NAMES[$svc]}:k8s"
    echo -e "${GRAY}   Сборка: $svc...${NC}"
    docker build -t "$tag" "${SERVICES[$svc]}"
    [ $? -ne 0 ] && echo -e "${RED}Ошибка сборки $svc${NC}" && exit 1

    echo -e "${GRAY}   Публикация: $tag...${NC}"
    docker push "$tag"
    [ $? -ne 0 ] && echo -e "${RED}Ошибка публикации $svc${NC}" && exit 1
done

echo -e "${YELLOW}7. Деплой микросервисов...${NC}"

# imagePullPolicy=Always — ноды kind тянут образы из локального registry
helm upgrade --install bridge ./k8s/charts/app-chart \
    --namespace iot-system \
    --set image.repository=$REGISTRY/diplomat/bridge \
    --set image.tag=k8s \
    --set image.pullPolicy=Always \
    --set replicaCount=1 \
    --set service.port=8080 \
    --set secretName=iot-secrets \
    --set autoscaling.enabled=true \
    --set autoscaling.minReplicas=1 \
    --set probes.readinessInitialDelay=70 \
    --set probes.livenessInitialDelay=100

helm upgrade --install consumer ./k8s/charts/app-chart \
    --namespace iot-system \
    --set image.repository=$REGISTRY/diplomat/consumer \
    --set image.tag=k8s \
    --set image.pullPolicy=Always \
    --set replicaCount=1 \
    --set service.port=8081 \
    --set secretName=iot-secrets \
    --set probes.readinessInitialDelay=100 \
    --set probes.livenessInitialDelay=150

helm upgrade --install generator ./k8s/charts/app-chart \
    --namespace iot-system \
    --set image.repository=$REGISTRY/diplomat/generator \
    --set image.tag=k8s \
    --set image.pullPolicy=Always \
    --set replicaCount=1 \
    --set probes.enabled=false

echo -e "${YELLOW}8. Services и ServiceMonitor...${NC}"
kubectl apply -f k8s/monitoring/services.yaml

echo -e "${GREEN}=== Стенд запущен! ===${NC}"
kubectl get pods -n iot-system