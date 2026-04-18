param(
  [int]$Port = 4000,
  [string]$HostIp = ""
)

$ErrorActionPreference = "Stop"

function Get-PreferredPrivateIPv4 {
  $defaultRoutes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric, ifMetric

  foreach ($route in $defaultRoutes) {
    $candidate = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue |
      Where-Object {
        $_.IPAddress -ne "127.0.0.1" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.PrefixOrigin -ne "WellKnown"
      } |
      Select-Object -First 1

    if ($candidate -and $candidate.IPAddress) {
      return $candidate.IPAddress
    }
  }

  return $null
}

if ([string]::IsNullOrWhiteSpace($HostIp)) {
  $HostIp = Get-PreferredPrivateIPv4
}

if ([string]::IsNullOrWhiteSpace($HostIp)) {
  Write-Error "Could not detect your PC LAN IPv4 address automatically. Rerun with -HostIp <YOUR_PC_WIFI_IP>."
}

# If backend switched to fallback port, use it automatically.
if ($Port -eq 4000) {
  $preferred = Test-NetConnection -ComputerName "127.0.0.1" -Port 4000 -WarningAction SilentlyContinue
  $fallback = Test-NetConnection -ComputerName "127.0.0.1" -Port 4001 -WarningAction SilentlyContinue
  if (-not $preferred.TcpTestSucceeded -and $fallback.TcpTestSucceeded) {
    Write-Host "Backend appears to be running on fallback port 4001. Using 4001." -ForegroundColor Yellow
    $Port = 4001
  }
}

$baseUrl = "http://$HostIp`:$Port"
Write-Host "Using API_BASE_URL=$baseUrl" -ForegroundColor Green
Write-Host "Make sure backend is running on 0.0.0.0:$Port and phone is on same Wi-Fi." -ForegroundColor Yellow

& flutter run "--dart-define=API_BASE_URL=$baseUrl"
