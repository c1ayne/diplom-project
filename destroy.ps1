# destroy.ps1
function Write-Red($text) { Write-Host $text -ForegroundColor Red }
function Write-Green($text) { Write-Host $text -ForegroundColor Green }
function Write-Yellow($text) { Write-Host $text -ForegroundColor Yellow }

Write-Red "!!! ПОЛНОЕ УДАЛЕНИЕ СТЕНДА !!!"
Write-Host "Namespace iot-system будет удален. Ctrl+C для отмены."
for ($i = 5; $i -ge 1; $i--) { Write-Host "$i..." -ForegroundColor Yellow; Start-Sleep 1 }

kubectl delete namespace iot-system

Write-Yellow "Ожидание завершения..."
$elapsed = 0
while ($elapsed -lt 60) {
    kubectl get namespace iot-system 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { break }
    Start-Sleep 3; $elapsed += 3
}
Write-Green "=== Стенд удален. ==="