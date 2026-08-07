# Wire every USB phone to the AI backend on this PC.
# Run from the project root, then restart flutter on each phone.

$ErrorActionPreference = "Continue"
$port = 8000

Write-Host "=== ConvoBridge phone connect ===" -ForegroundColor Cyan

# Show LAN IP phones should use over Wi‑Fi
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -like '192.168.*' } |
  Select-Object -First 1 -ExpandProperty IPAddress)
if ($ip) {
  Write-Host "PC LAN IP: $ip"
  Write-Host "App URL:   http://${ip}:$port"
} else {
  Write-Host "No 192.168.* IP found — check Wi‑Fi." -ForegroundColor Yellow
}

# adb reverse for EACH device (plain `adb reverse` fails with 2 phones)
$devices = adb devices | Select-String "`tdevice$" | ForEach-Object {
  ($_ -split "\s+")[0]
}
if (-not $devices) {
  Write-Host "No Android devices in 'device' state." -ForegroundColor Red
  exit 1
}

foreach ($id in $devices) {
  Write-Host "adb reverse $id  tcp:$port -> tcp:$port"
  adb -s $id reverse tcp:$port tcp:$port
}

Write-Host ""
Write-Host "Next:" -ForegroundColor Green
Write-Host "  1. Restart backend:  python run_dev.py   (must say 0.0.0.0:$port)"
Write-Host "  2. On each phone, full restart the Flutter app (not hot reload)"
Write-Host "  3. Phone browser test: http://${ip}:$port/health"
Write-Host ""
Write-Host "Or run with explicit URL:"
Write-Host "  flutter run -d <DEVICE_ID> --dart-define=AI_SERVER_BASE_URL=http://${ip}:$port"
