# scale.ps1 - Ручное управление количеством реплик компонентов
#
# Использование:
#   .\scale.ps1 -Service bridge -Replicas 3
#   .\scale.ps1 -Service consumer -Replicas 2
#   .\scale.ps1 -Service kafka -Replicas 3
#   .\scale.ps1 -Service emqx -Replicas 2
#   .\scale.ps1 -Status
#
# Допустимые значения -Service: bridge, consumer, generator, emqx, kafka

param(
    [ValidateSet("bridge", "consumer", "generator", "emqx", "kafka", "postgresql")]
    [string]$Service,

    [ValidateRange(0, 20)]
    [int]$Replicas,

    [switch]$Status
)

function Write-Green($text)  { Write-Host $text -ForegroundColor Green }
function Write-Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Write-Red($text)    { Write-Host $text -ForegroundColor Red }
function Write-Cyan($text)   { Write-Host $text -ForegroundColor Cyan }

$NAMESPACE = "iot-system"

# --- Режим просмотра текущего состояния ---
if ($Status) {
    Write-Cyan "=== Текущее состояние реплик ==="
    Write-Host ""

    # Микросервисы (Deployment)
    foreach ($svc in @("bridge", "consumer", "generator")) {
        $desired = kubectl get deployment $svc -n $NAMESPACE -o jsonpath="{.spec.replicas}" 2>$null
        $ready   = kubectl get deployment $svc -n $NAMESPACE -o jsonpath="{.status.readyReplicas}" 2>$null
        $hpaInfo = kubectl get hpa $svc -n $NAMESPACE -o jsonpath="{.spec.minReplicas}-{.spec.maxReplicas}" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $hpaStr = if ($hpaInfo) { " (HPA: min=$($hpaInfo.Split('-')[0]) max=$($hpaInfo.Split('-')[1]))" } else { "" }
            Write-Host ("  {0,-12} [Deployment]  желаемых: {1,2}  готовых: {2,2}{3}" -f $svc, $desired, $ready, $hpaStr)
        } else {
            Write-Host ("  {0,-12} не развёрнут" -f $svc) -ForegroundColor Gray
        }
    }

    # EMQX (StatefulSet)
    $emqxReady   = kubectl get statefulset my-emqx -n $NAMESPACE -o jsonpath="{.status.readyReplicas}" 2>$null
    $emqxDesired = kubectl get statefulset my-emqx -n $NAMESPACE -o jsonpath="{.spec.replicas}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host ("  {0,-12} [StatefulSet] желаемых: {1,2}  готовых: {2,2}" -f "emqx", $emqxDesired, $emqxReady)
    } else {
        Write-Host ("  {0,-12} не развёрнут" -f "emqx") -ForegroundColor Gray
    }

    # Kafka (KafkaNodePool)
    $kafkaReplicas = kubectl get kafkanodepool dual-role -n $NAMESPACE -o jsonpath="{.spec.replicas}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host ("  {0,-12} [KafkaNodePool] реплик: {1,2}" -f "kafka", $kafkaReplicas)
    } else {
        Write-Host ("  {0,-12} не развёрнут" -f "kafka") -ForegroundColor Gray
    }

    # PostgreSQL (StatefulSet read-реплики)
    $pgDesired = kubectl get statefulset my-db-postgresql-read -n $NAMESPACE -o jsonpath="{.spec.replicas}" 2>$null
    $pgReady   = kubectl get statefulset my-db-postgresql-read -n $NAMESPACE -o jsonpath="{.status.readyReplicas}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host ("  {0,-12} [StatefulSet]  желаемых: {1,2}  готовых: {2,2}  (primary всегда 1)" -f "postgresql", $pgDesired, $pgReady)
    } else {
        Write-Host ("  {0,-12} не развёрнут или режим standalone" -f "postgresql") -ForegroundColor Gray
    }

    Write-Host ""
    Write-Cyan "Ноды кластера:"
    kubectl get nodes
    exit 0
}

# --- Валидация параметров ---
if (-not $Service) {
    Write-Red "Укажи компонент: -Service <bridge|consumer|generator|emqx|kafka|postgresql>"
    Write-Yellow "Пример: .\scale.ps1 -Service bridge -Replicas 3"
    Write-Yellow "Статус: .\scale.ps1 -Status"
    exit 1
}
if ($PSBoundParameters.ContainsKey('Replicas') -eq $false) {
    Write-Red "Укажи количество реплик: -Replicas <число>"
    exit 1
}

# --- Масштабирование ---
switch ($Service) {

    # Микросервисы - через kubectl scale deployment
    { $_ -in "bridge","consumer","generator" } {
        kubectl get deployment $Service -n $NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Red "Deployment '$Service' не найден"; exit 1 }

        $hpaExists = kubectl get hpa $Service -n $NAMESPACE 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Yellow "Внимание: для '$Service' активен HPA - ручное значение может быть переопределено."
            Write-Yellow "Для отключения: kubectl delete hpa $Service -n $NAMESPACE"
            Write-Host ""
        }

        $current = kubectl get deployment $Service -n $NAMESPACE -o jsonpath="{.spec.replicas}"
        Write-Yellow "Масштабирование '$Service': $current -> $Replicas реплик..."
        kubectl scale deployment $Service -n $NAMESPACE --replicas=$Replicas
        if ($LASTEXITCODE -ne 0) { Write-Red "Ошибка масштабирования"; exit 1 }

        Write-Yellow "Ожидание готовности подов..."
        kubectl rollout status deployment/$Service -n $NAMESPACE --timeout=120s
        if ($LASTEXITCODE -ne 0) { Write-Red "Поды не готовы. Проверь: kubectl get pods -n $NAMESPACE"; exit 1 }

        $ready = kubectl get deployment $Service -n $NAMESPACE -o jsonpath="{.status.readyReplicas}"
        Write-Green "=== '$Service' масштабирован: $ready/$Replicas готовы ==="
        kubectl get pods -n $NAMESPACE -l app=$Service
    }

    # EMQX - через kubectl scale statefulset
    "emqx" {
        kubectl get statefulset my-emqx -n $NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Red "StatefulSet 'my-emqx' не найден"; exit 1 }

        $current = kubectl get statefulset my-emqx -n $NAMESPACE -o jsonpath="{.spec.replicas}"
        Write-Yellow "Масштабирование EMQX: $current -> $Replicas реплик..."
        kubectl scale statefulset my-emqx -n $NAMESPACE --replicas=$Replicas
        if ($LASTEXITCODE -ne 0) { Write-Red "Ошибка масштабирования EMQX"; exit 1 }

        Write-Yellow "Ожидание готовности подов..."
        kubectl rollout status statefulset/my-emqx -n $NAMESPACE --timeout=120s
        if ($LASTEXITCODE -ne 0) { Write-Red "Поды EMQX не готовы. Проверь: kubectl get pods -n $NAMESPACE"; exit 1 }

        $ready = kubectl get statefulset my-emqx -n $NAMESPACE -o jsonpath="{.status.readyReplicas}"
        Write-Green "=== EMQX масштабирован: $ready/$Replicas готовы ==="
        kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=emqx
    }

    # Kafka - через патч KafkaNodePool (Strimzi API)
    "kafka" {
        kubectl get kafkanodepool dual-role -n $NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Red "KafkaNodePool 'dual-role' не найден"; exit 1 }

        if ($Replicas -lt 1) { Write-Red "Kafka требует минимум 1 реплику"; exit 1 }

        $current = kubectl get kafkanodepool dual-role -n $NAMESPACE -o jsonpath="{.spec.replicas}"
        Write-Yellow "Масштабирование Kafka: $current -> $Replicas брокеров..."
        Write-Yellow "Внимание: при уменьшении числа брокеров убедись что replication.factor <= $Replicas"

        kubectl patch kafkanodepool dual-role -n $NAMESPACE `
            --type=merge `
            -p "{`"spec`":{`"replicas`":$Replicas}}"
        if ($LASTEXITCODE -ne 0) { Write-Red "Ошибка патча KafkaNodePool"; exit 1 }

        Write-Yellow "Ожидание готовности Kafka (может занять несколько минут)..."
        kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n $NAMESPACE
        if ($LASTEXITCODE -ne 0) { Write-Red "Kafka не готова. Проверь: kubectl get pods -n $NAMESPACE"; exit 1 }

        Write-Green "=== Kafka масштабирована до $Replicas брокеров ==="
        kubectl get pods -n $NAMESPACE -l strimzi.io/cluster=my-cluster
    }
    # PostgreSQL read-реплики — kubectl scale statefulset
    "postgresql" {
        kubectl get statefulset my-db-postgresql-read -n $NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Red "StatefulSet 'my-db-postgresql-read' не найден"
            Write-Yellow "Убедись что postgres-values.yaml содержит architecture: replication"
            exit 1
        }

        $current = kubectl get statefulset my-db-postgresql-read -n $NAMESPACE -o jsonpath="{.spec.replicas}"
        Write-Yellow "Масштабирование PostgreSQL read-реплик: $current -> $Replicas..."
        Write-Yellow "Primary (мастер) всегда остаётся в 1 экземпляре"

        kubectl scale statefulset my-db-postgresql-read -n $NAMESPACE --replicas=$Replicas
        if ($LASTEXITCODE -ne 0) { Write-Red "Ошибка масштабирования PostgreSQL"; exit 1 }

        Write-Yellow "Ожидание готовности реплик..."
        kubectl rollout status statefulset/my-db-postgresql-read -n $NAMESPACE --timeout=120s
        if ($LASTEXITCODE -ne 0) { Write-Red "Реплики не готовы. Проверь: kubectl get pods -n $NAMESPACE"; exit 1 }

        $ready = kubectl get statefulset my-db-postgresql-read -n $NAMESPACE -o jsonpath="{.status.readyReplicas}"
        Write-Green "=== PostgreSQL: $ready/$Replicas read-реплик готовы (+ 1 primary) ==="
        kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=read
    }
}
