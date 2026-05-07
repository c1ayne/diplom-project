# setup-kind.ps1 - Создание kind-кластера с локальным Docker Registry
# Запускать ОДИН РАЗ перед первым start.ps1
# Повторный запуск безопасен: существующие ресурсы пропускаются

function Write-Green($text)  { Write-Host $text -ForegroundColor Green }
function Write-Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Write-Red($text)    { Write-Host $text -ForegroundColor Red }

foreach ($tool in @("kind", "kubectl", "helm", "docker")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Red "Не найден инструмент: $tool. Установи: choco install $tool"
        exit 1
    }
}

$REGISTRY_NAME = "kind-registry"
$REGISTRY_PORT = "5001"
$CLUSTER_NAME  = "iot-cluster"

Write-Green "=== Настройка kind-кластера с локальным registry ==="

# --- 1. Локальный Docker Registry ---
Write-Yellow "1. Локальный Docker Registry..."

$registryRunning = docker inspect -f '{{.State.Running}}' $REGISTRY_NAME 2>$null
if ($registryRunning -eq "true") {
    Write-Host "   Registry уже запущен - пропуск" -ForegroundColor Gray
} else {
    docker run -d --restart=always --name $REGISTRY_NAME -p "${REGISTRY_PORT}:5000" registry:2
    if ($LASTEXITCODE -ne 0) { Write-Red "Ошибка запуска registry"; exit 1 }
    Write-Host "   Registry запущен на localhost:$REGISTRY_PORT" -ForegroundColor Gray
}

# --- 2. Kind-кластер ---
Write-Yellow "2. Kind-кластер ($CLUSTER_NAME)..."

$clusterExists = kind get clusters 2>$null | Select-String -Pattern "^$CLUSTER_NAME$"
if ($clusterExists) {
    Write-Host "   Кластер уже существует - пропуск" -ForegroundColor Gray
} else {
    kind create cluster --name $CLUSTER_NAME --config kind-config.yaml --wait 120s
    if ($LASTEXITCODE -ne 0) { Write-Red "Ошибка создания кластера"; exit 1 }
    Write-Host "   Кластер создан: 1 control-plane + 2 workers" -ForegroundColor Gray
}

kubectl config use-context "kind-$CLUSTER_NAME"

# --- 3. Подключение registry к сети kind ---
Write-Yellow "3. Подключение registry к сети kind..."

$networkInfo = docker network inspect kind --format '{{range .Containers}}{{.Name}} {{end}}' 2>$null
if ($networkInfo -match $REGISTRY_NAME) {
    Write-Host "   Уже подключён - пропуск" -ForegroundColor Gray
} else {
    docker network connect kind $REGISTRY_NAME 2>$null
    Write-Host "   Registry подключён к сети kind" -ForegroundColor Gray
}

# --- 4. ConfigMap для обнаружения registry нодами ---
Write-Yellow "4. Регистрация registry в кластере..."

[string]$cm = "apiVersion: v1`nkind: ConfigMap`nmetadata:`n  name: local-registry-hosting`n  namespace: kube-public`ndata:`n  localRegistryHosting.v1: |`n    host: `"localhost:$REGISTRY_PORT`"`n    help: `"https://kind.sigs.k8s.io/docs/user/local-registry/`""
$cm | kubectl apply -f -

# --- Итог ---
Write-Green "=== Кластер готов! ==="
Write-Host ""
Write-Host "Ноды кластера:" -ForegroundColor Cyan
kubectl get nodes
Write-Host ""
Write-Host "Registry : localhost:$REGISTRY_PORT" -ForegroundColor Cyan
Write-Host "Контекст : kind-$CLUSTER_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Yellow "Следующий шаг: запусти start.ps1"
