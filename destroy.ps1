# destroy.ps1 - Полное удаление стенда
# По умолчанию удаляет только namespace iot-system.
# С флагом -DeleteCluster удаляет также kind-кластер и локальный registry.

param(
    [switch]$DeleteCluster
)

function Write-Red($text)    { Write-Host $text -ForegroundColor Red }
function Write-Green($text)  { Write-Host $text -ForegroundColor Green }
function Write-Yellow($text) { Write-Host $text -ForegroundColor Yellow }

if ($DeleteCluster) {
    Write-Red "!!! ПОЛНОЕ УДАЛЕНИЕ: namespace + kind-кластер + registry !!!"
} else {
    Write-Red "!!! УДАЛЕНИЕ NAMESPACE iot-system (кластер и registry сохраняются) !!!"
}
Write-Host "Ctrl+C для отмены." -ForegroundColor Yellow
for ($i = 5; $i -ge 1; $i--) { Write-Host "$i..." -ForegroundColor Yellow; Start-Sleep 1 }

# --- Удаление namespace ---
kubectl delete namespace iot-system

Write-Yellow "Ожидание завершения удаления namespace..."
$elapsed = 0
while ($elapsed -lt 60) {
    kubectl get namespace iot-system 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { break }
    Start-Sleep 3; $elapsed += 3
}

# --- Опциональное удаление кластера и registry ---
if ($DeleteCluster) {
    Write-Yellow "Удаление kind-кластера..."
    kind delete cluster --name iot-cluster

    Write-Yellow "Удаление локального registry..."
    docker stop kind-registry 2>$null
    docker rm   kind-registry 2>$null
}

Write-Green "=== Стенд удалён. ==="
