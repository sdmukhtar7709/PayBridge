param(
  [int]$Port = 4000,
  [string]$BaseUrl = ""
)

$ErrorActionPreference = "Stop"

# Ensure a device is connected.
$devices = & adb devices | Select-String -Pattern "\tdevice$"
if (-not $devices) {
  Write-Error "No adb device found. Enable USB debugging and authorize the PC."
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

# Reverse the backend port over USB.
& adb reverse "tcp:$Port" "tcp:$Port" | Out-Null
$reverseList = & adb reverse --list
$hasReverse = $reverseList | Select-String -Pattern "tcp:$Port\s+tcp:$Port"

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  if ($hasReverse) {
    $BaseUrl = "http://127.0.0.1:$Port"
  }
  else {
    Write-Error "adb reverse is not active for port $Port. Reconnect USB and rerun, or pass -BaseUrl http://<YOUR_PC_LAN_IP>:$Port"
  }
}

if (($BaseUrl -match "127.0.0.1|localhost") -and (-not $hasReverse)) {
  Write-Error "BaseUrl '$BaseUrl' requires adb reverse, but no reverse mapping exists for port $Port."
}

# Run Flutter with a local base URL.
& flutter run "--dart-define=API_BASE_URL=$BaseUrl"
