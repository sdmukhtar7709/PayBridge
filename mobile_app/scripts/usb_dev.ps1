param(
  [int]$Port = 4000,
  [string]$BaseUrl = "http://127.0.0.1:4000"
)

$ErrorActionPreference = "Stop"

# Ensure a device is connected.
$devices = & adb devices | Select-String -Pattern "\tdevice$"
if (-not $devices) {
  Write-Error "No adb device found. Enable USB debugging and authorize the PC."
}

# Reverse the backend port over USB.
& adb reverse "tcp:$Port" "tcp:$Port" | Out-Null

# Run Flutter with a local base URL.
& flutter run "--dart-define=API_BASE_URL=$BaseUrl"
