# monitor.ps1 — Развертывание мониторинга из локальных файлов

function Write-Green($text) { Write-Host $text -ForegroundColor Green }
function Write-Yellow($text) { Write-Host $text -ForegroundColor Yellow }

Write-Green "=== Развертывание мониторинга ==="

Write-Yellow "1. Prometheus + Grafana..."
helm upgrade --install my-monitoring k8s\install\helm-charts\kube-prometheus-stack-69.2.0.tgz `
    --namespace iot-system `
    --set prometheus-node-exporter.enabled=false `
    --set kubeStateMetrics.enabled=false `
    --set alertmanager.enabled=false `
    --wait

Write-Yellow "2. ServiceMonitor..."
kubectl apply -f k8s\monitoring\services.yaml
kubectl apply -f k8s\monitoring\servicemonitor.yaml

Write-Yellow "3. Пароль Grafana..."
$b64 = kubectl get secret --namespace iot-system my-monitoring-grafana -o jsonpath="{.data.admin-password}"
$pass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))

Write-Green "=== Мониторинг готов! ==="
Write-Host "URL    : http://localhost:3000" -ForegroundColor Cyan
Write-Host "Логин  : admin" -ForegroundColor Cyan
Write-Host "Пароль : $pass" -ForegroundColor Cyan
Write-Host ""
Write-Yellow "Запусти в отдельном терминале:"
Write-Host "kubectl port-forward svc/my-monitoring-grafana 3000:80 -n iot-system"