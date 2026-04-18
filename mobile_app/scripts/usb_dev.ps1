param(
  [string]$BaseUrl = "https://cashio-backends.onrender.com"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  Write-Error "BaseUrl cannot be empty. Pass -BaseUrl https://cashio-backends.onrender.com or another HTTPS endpoint."
}

# Run Flutter with an internet-reachable base URL.
& flutter run "--dart-define=API_BASE_URL=$BaseUrl"
