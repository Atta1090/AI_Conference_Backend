# Run Flutter against the Google Cloud GPU backend (no app code changes).
# Usage:
#   .\cloud_gpu\flutter_run_cloud.ps1 -AiServerUrl "http://34.xxx.xxx.xxx:8000"

param(
    [Parameter(Mandatory = $true)]
    [string]$AiServerUrl
)

$ErrorActionPreference = "Stop"

$frontEnd = Join-Path $PSScriptRoot "..\front_end" | Resolve-Path
Set-Location $frontEnd

Write-Host "AI server => $AiServerUrl"
Write-Host "Starting Flutter (phone needs internet; no adb reverse for cloud)..."

flutter run --dart-define=AI_SERVER_BASE_URL=$AiServerUrl
