#!/bin/bash
# scale.sh — Ручное управление количеством реплик компонентов
#
# Использование:
#   ./scale.sh bridge 3
#   ./scale.sh consumer 2
#   ./scale.sh generator 5
#   ./scale.sh emqx 2
#   ./scale.sh kafka 3
#   ./scale.sh postgresql 2   # масштабирует только read-реплики
#   ./scale.sh --status

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

NAMESPACE="iot-system"

# --- Режим просмотра текущего состояния ---
if [ "$1" = "--status" ]; then
    echo -e "${CYAN}=== Текущее состояние реплик ===${NC}"
    echo ""

    # Микросервисы (Deployment)
    for svc in bridge consumer generator; do
        desired=$(kubectl get deployment "$svc" -n "$NAMESPACE" \
            -o jsonpath="{.spec.replicas}" 2>/dev/null)
        ready=$(kubectl get deployment "$svc" -n "$NAMESPACE" \
            -o jsonpath="{.status.readyReplicas}" 2>/dev/null)
        hpa_min=$(kubectl get hpa "$svc" -n "$NAMESPACE" \
            -o jsonpath="{.spec.minReplicas}" 2>/dev/null)
        hpa_max=$(kubectl get hpa "$svc" -n "$NAMESPACE" \
            -o jsonpath="{.spec.maxReplicas}" 2>/dev/null)

        if [ -n "$desired" ]; then
            hpa_str=""
            [ -n "$hpa_min" ] && hpa_str=" (HPA: min=$hpa_min max=$hpa_max)"
            printf "  %-12s [Deployment]    желаемых: %2s  готовых: %2s%s\n" \
                "$svc" "${desired:--}" "${ready:--}" "$hpa_str"
        else
            echo -e "  $(printf '%-12s' $svc) ${GRAY}не развёрнут${NC}"
        fi
    done

    # EMQX (StatefulSet)
    emqx_desired=$(kubectl get statefulset my-emqx -n "$NAMESPACE" \
        -o jsonpath="{.spec.replicas}" 2>/dev/null)
    emqx_ready=$(kubectl get statefulset my-emqx -n "$NAMESPACE" \
        -o jsonpath="{.status.readyReplicas}" 2>/dev/null)
    if [ -n "$emqx_desired" ]; then
        printf "  %-12s [StatefulSet]   желаемых: %2s  готовых: %2s\n" \
            "emqx" "${emqx_desired:--}" "${emqx_ready:--}"
    else
        echo -e "  $(printf '%-12s' emqx) ${GRAY}не развёрнут${NC}"
    fi

    # Kafka (KafkaNodePool)
    kafka_replicas=$(kubectl get kafkanodepool dual-role -n "$NAMESPACE" \
        -o jsonpath="{.spec.replicas}" 2>/dev/null)
    if [ -n "$kafka_replicas" ]; then
        printf "  %-12s [KafkaNodePool]  реплик: %2s\n" "kafka" "$kafka_replicas"
    else
        echo -e "  $(printf '%-12s' kafka) ${GRAY}не развёрнут${NC}"
    fi

    # PostgreSQL read-реплики (StatefulSet)
    pg_desired=$(kubectl get statefulset my-db-postgresql-read -n "$NAMESPACE" \
        -o jsonpath="{.spec.replicas}" 2>/dev/null)
    pg_ready=$(kubectl get statefulset my-db-postgresql-read -n "$NAMESPACE" \
        -o jsonpath="{.status.readyReplicas}" 2>/dev/null)
    if [ -n "$pg_desired" ]; then
        printf "  %-12s [StatefulSet]   желаемых: %2s  готовых: %2s  (primary всегда 1)\n" \
            "postgresql" "${pg_desired:--}" "${pg_ready:--}"
    else
        echo -e "  $(printf '%-12s' postgresql) ${GRAY}не развёрнут или режим standalone${NC}"
    fi

    echo ""
    echo -e "${CYAN}Ноды кластера:${NC}"
    kubectl get nodes
    exit 0
fi

# --- Валидация аргументов ---
SERVICE="$1"
REPLICAS="$2"

if [ -z "$SERVICE" ] || [ -z "$REPLICAS" ]; then
    echo -e "${RED}Использование: ./scale.sh <service> <replicas>${NC}"
    echo -e "${YELLOW}Допустимые сервисы: bridge, consumer, generator, emqx, kafka, postgresql${NC}"
    echo -e "${YELLOW}Пример: ./scale.sh bridge 3${NC}"
    echo -e "${YELLOW}Статус: ./scale.sh --status${NC}"
    exit 1
fi

VALID=false
for v in bridge consumer generator emqx kafka postgresql; do
    [ "$SERVICE" = "$v" ] && VALID=true && break
done
if ! $VALID; then
    echo -e "${RED}Неизвестный сервис: $SERVICE${NC}"
    echo -e "${YELLOW}Допустимые: bridge, consumer, generator, emqx, kafka, postgresql${NC}"
    exit 1
fi

if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Количество реплик должно быть целым числом: $REPLICAS${NC}"
    exit 1
fi

# --- Масштабирование ---

case "$SERVICE" in

    # Микросервисы — kubectl scale deployment
    bridge|consumer|generator)
        if ! kubectl get deployment "$SERVICE" -n "$NAMESPACE" &>/dev/null; then
            echo -e "${RED}Deployment '$SERVICE' не найден в namespace $NAMESPACE${NC}"
            echo -e "${YELLOW}Запусти start.sh для развёртывания стенда${NC}"
            exit 1
        fi

        if kubectl get hpa "$SERVICE" -n "$NAMESPACE" &>/dev/null; then
            echo -e "${YELLOW}Внимание: для '$SERVICE' активен HPA — ручное значение может быть переопределено.${NC}"
            echo -e "${YELLOW}Для отключения: kubectl delete hpa $SERVICE -n $NAMESPACE${NC}"
            echo ""
        fi

        current=$(kubectl get deployment "$SERVICE" -n "$NAMESPACE" -o jsonpath="{.spec.replicas}")
        echo -e "${YELLOW}Масштабирование '$SERVICE': $current -> $REPLICAS реплик...${NC}"

        kubectl scale deployment "$SERVICE" -n "$NAMESPACE" --replicas="$REPLICAS"
        [ $? -ne 0 ] && echo -e "${RED}Ошибка масштабирования${NC}" && exit 1

        echo -e "${YELLOW}Ожидание готовности подов...${NC}"
        kubectl rollout status "deployment/$SERVICE" -n "$NAMESPACE" --timeout=120s
        if [ $? -ne 0 ]; then
            echo -e "${RED}Поды не готовы. Проверь: kubectl get pods -n $NAMESPACE${NC}"
            exit 1
        fi

        ready=$(kubectl get deployment "$SERVICE" -n "$NAMESPACE" -o jsonpath="{.status.readyReplicas}")
        echo -e "${GREEN}=== '$SERVICE' масштабирован: $ready/$REPLICAS готовы ===${NC}"
        echo ""
        kubectl get pods -n "$NAMESPACE" -l "app=$SERVICE"
        ;;

    # EMQX — kubectl scale statefulset
    emqx)
        if ! kubectl get statefulset my-emqx -n "$NAMESPACE" &>/dev/null; then
            echo -e "${RED}StatefulSet 'my-emqx' не найден${NC}"
            exit 1
        fi

        current=$(kubectl get statefulset my-emqx -n "$NAMESPACE" -o jsonpath="{.spec.replicas}")
        echo -e "${YELLOW}Масштабирование EMQX: $current -> $REPLICAS реплик...${NC}"

        kubectl scale statefulset my-emqx -n "$NAMESPACE" --replicas="$REPLICAS"
        [ $? -ne 0 ] && echo -e "${RED}Ошибка масштабирования EMQX${NC}" && exit 1

        echo -e "${YELLOW}Ожидание готовности подов...${NC}"
        kubectl rollout status statefulset/my-emqx -n "$NAMESPACE" --timeout=120s
        if [ $? -ne 0 ]; then
            echo -e "${RED}Поды EMQX не готовы. Проверь: kubectl get pods -n $NAMESPACE${NC}"
            exit 1
        fi

        ready=$(kubectl get statefulset my-emqx -n "$NAMESPACE" -o jsonpath="{.status.readyReplicas}")
        echo -e "${GREEN}=== EMQX масштабирован: $ready/$REPLICAS готовы ===${NC}"
        echo ""
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=emqx
        ;;

    # Kafka — патч KafkaNodePool (Strimzi API)
    kafka)
        if ! kubectl get kafkanodepool dual-role -n "$NAMESPACE" &>/dev/null; then
            echo -e "${RED}KafkaNodePool 'dual-role' не найден${NC}"
            exit 1
        fi

        if [ "$REPLICAS" -lt 1 ]; then
            echo -e "${RED}Kafka требует минимум 1 реплику${NC}"
            exit 1
        fi

        current=$(kubectl get kafkanodepool dual-role -n "$NAMESPACE" -o jsonpath="{.spec.replicas}")
        echo -e "${YELLOW}Масштабирование Kafka: $current -> $REPLICAS брокеров...${NC}"
        echo -e "${YELLOW}Внимание: при уменьшении числа брокеров убедись что replication.factor <= $REPLICAS${NC}"

        kubectl patch kafkanodepool dual-role -n "$NAMESPACE" \
            --type=merge \
            -p "{\"spec\":{\"replicas\":$REPLICAS}}"
        [ $? -ne 0 ] && echo -e "${RED}Ошибка патча KafkaNodePool${NC}" && exit 1

        echo -e "${YELLOW}Ожидание готовности Kafka (может занять несколько минут)...${NC}"
        kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n "$NAMESPACE"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Kafka не готова. Проверь: kubectl get pods -n $NAMESPACE${NC}"
            exit 1
        fi

        echo -e "${GREEN}=== Kafka масштабирована до $REPLICAS брокеров ===${NC}"
        echo ""
        kubectl get pods -n "$NAMESPACE" -l strimzi.io/cluster=my-cluster
        ;;

    # PostgreSQL read-реплики — kubectl scale statefulset
    postgresql)
        if ! kubectl get statefulset my-db-postgresql-read -n "$NAMESPACE" &>/dev/null; then
            echo -e "${RED}StatefulSet 'my-db-postgresql-read' не найден${NC}"
            echo -e "${YELLOW}Убедись что postgres-values.yaml содержит architecture: replication${NC}"
            exit 1
        fi

        current=$(kubectl get statefulset my-db-postgresql-read -n "$NAMESPACE" -o jsonpath="{.spec.replicas}")
        echo -e "${YELLOW}Масштабирование PostgreSQL read-реплик: $current -> $REPLICAS...${NC}"
        echo -e "${YELLOW}Primary (мастер) всегда остаётся в 1 экземпляре${NC}"

        kubectl scale statefulset my-db-postgresql-read -n "$NAMESPACE" --replicas="$REPLICAS"
        [ $? -ne 0 ] && echo -e "${RED}Ошибка масштабирования PostgreSQL${NC}" && exit 1

        echo -e "${YELLOW}Ожидание готовности реплик...${NC}"
        kubectl rollout status statefulset/my-db-postgresql-read -n "$NAMESPACE" --timeout=120s
        if [ $? -ne 0 ]; then
            echo -e "${RED}Реплики не готовы. Проверь: kubectl get pods -n $NAMESPACE${NC}"
            exit 1
        fi

        ready=$(kubectl get statefulset my-db-postgresql-read -n "$NAMESPACE" -o jsonpath="{.status.readyReplicas}")
        echo -e "${GREEN}=== PostgreSQL: $ready/$REPLICAS read-реплик готовы (+ 1 primary) ===${NC}"
        echo ""
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=read
        ;;
esac
