# stop.ps1 - Остановка микросервисов (инфраструктура остаётся работать)

function Write-Red($text)   { Write-Host $text -ForegroundColor Red }
function Write-Green($text) { Write-Host $text -ForegroundColor Green }

Write-Red "=== Остановка микросервисов... ==="
helm uninstall bridge    -n iot-system
helm uninstall consumer  -n iot-system
helm uninstall generator -n iot-system
Write-Green "=== Готово. Инфраструктура (Kafka/EMQX/PostgreSQL) работает. ==="
