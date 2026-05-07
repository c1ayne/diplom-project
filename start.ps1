# start.ps1 - Развертывание стенда (kind + локальный registry)

function Write-Green($text)  { Write-Host $text -ForegroundColor Green }
function Write-Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Write-Red($text)    { Write-Host $text -ForegroundColor Red }

if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Red "Helm не найден. Установи: choco install kubernetes-helm -y"
    exit 1
}

# Адрес локального registry - образы пушатся сюда, kind тянет отсюда
$REGISTRY = "localhost:5001"

Write-Green "=== Запуск стенда ==="
kubectl create namespace iot-system --dry-run=client -o yaml | kubectl apply -f -

Write-Yellow "1. Strimzi Operator..."
(Get-Content k8s\install\strimzi-cluster-operator-0.45.0.yaml) `
    -replace 'namespace: myproject', 'namespace: iot-system' |
    kubectl apply -f - -n iot-system

Write-Yellow "Ожидание Strimzi..."
kubectl rollout status deployment/strimzi-cluster-operator -n iot-system --timeout=120s
if ($LASTEXITCODE -ne 0) { Write-Red "Strimzi не запустился"; exit 1 }
Start-Sleep -Seconds 15

Write-Yellow "2. EMQX..."
helm upgrade --install my-emqx k8s\install\helm-charts\emqx-5.8.9.tgz `
    --namespace iot-system `
    --set replicaCount=1 `
    --wait

Write-Yellow "3. PostgreSQL..."
helm upgrade --install my-db k8s\install\helm-charts\postgresql-18.6.2.tgz `
    --namespace iot-system `
    -f k8s\postgres-values.yaml `
    --wait

Write-Yellow "4. ConfigMap и Secret..."
kubectl apply -f k8s\configmap.yaml
kubectl apply -f k8s\secrets.yaml

Write-Yellow "5. Kafka-кластер..."
kubectl apply -f k8s\kafka-cluster.yaml
Write-Yellow "Ожидание Kafka (3-5 минут)..."
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n iot-system
if ($LASTEXITCODE -ne 0) { Write-Red "Kafka не готова"; exit 1 }

# --- Сборка и публикация образов в локальный registry ---
# В kind imagePullPolicy=Never не работает для образов не из registry.
# Все образы пушатся в localhost:5001, который смонтирован в каждую ноду как kind-registry:5000
Write-Yellow "6. Сборка и публикация образов..."

$services = @(
    @{ Name = "bridge";           Dir = ".\bridge";           Tag = "$REGISTRY/diplomat/bridge:k8s" },
    @{ Name = "consumer-service"; Dir = ".\consumer-service"; Tag = "$REGISTRY/diplomat/consumer:k8s" },
    @{ Name = "generator";        Dir = ".\generator";        Tag = "$REGISTRY/diplomat/generator:k8s" }
)

foreach ($svc in $services) {
    Write-Host "   Сборка: $($svc.Name)..." -ForegroundColor Gray
    docker build -t $svc.Tag $svc.Dir
    if ($LASTEXITCODE -ne 0) { Write-Red "Ошибка сборки $($svc.Name)"; exit 1 }

    Write-Host "   Публикация: $($svc.Tag)..." -ForegroundColor Gray
    docker push $svc.Tag
    if ($LASTEXITCODE -ne 0) { Write-Red "Ошибка публикации $($svc.Name)"; exit 1 }
}

Write-Yellow "7. Деплой микросервисов..."

helm upgrade --install bridge ./k8s/charts/app-chart `
    --namespace iot-system `
    --set image.repository=$REGISTRY/diplomat/bridge `
    --set image.tag=k8s `
    --set image.pullPolicy=Always `
    --set replicaCount=1 `
    --set service.port=8080 `
    --set secretName=iot-secrets `
    --set autoscaling.enabled=true `
    --set autoscaling.minReplicas=1 `
    --set probes.readinessInitialDelay=70 `
    --set probes.livenessInitialDelay=100

helm upgrade --install consumer ./k8s/charts/app-chart `
    --namespace iot-system `
    --set image.repository=$REGISTRY/diplomat/consumer `
    --set image.tag=k8s `
    --set image.pullPolicy=Always `
    --set replicaCount=1 `
    --set service.port=8081 `
    --set secretName=iot-secrets `
    --set probes.readinessInitialDelay=100 `
    --set probes.livenessInitialDelay=150

helm upgrade --install generator ./k8s/charts/app-chart `
    --namespace iot-system `
    --set image.repository=$REGISTRY/diplomat/generator `
    --set image.tag=k8s `
    --set image.pullPolicy=Always `
    --set replicaCount=1 `
    --set probes.enabled=false

Write-Yellow "8. Services и ServiceMonitor..."
kubectl apply -f k8s\monitoring\services.yaml

Write-Green "=== Стенд запущен! ==="
kubectl get pods -n iot-system