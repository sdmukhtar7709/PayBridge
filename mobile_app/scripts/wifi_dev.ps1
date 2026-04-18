param(
  [string]$BaseUrl = "https://cashio-backends.onrender.com"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  Write-Error "BaseUrl cannot be empty. Pass -BaseUrl https://cashio-backends.onrender.com or another HTTPS endpoint."
}

Write-Host "Using API_BASE_URL=$BaseUrl" -ForegroundColor Green
Write-Host "Using deployed backend over the internet." -ForegroundColor Yellow

& flutter run "--dart-define=API_BASE_URL=$BaseUrl"
