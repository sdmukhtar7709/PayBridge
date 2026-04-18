# paybridge

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Run On Physical Android (USB Recommended)

For USB debugging on a physical Android phone, this project now defaults to loopback URLs:

- `http://127.0.0.1:4000`
- fallback `http://127.0.0.1:4001`

This requires `adb reverse` mapping from device port to your PC backend port.

1. Start backend on your PC (preferred port `4000`; fallback may be `4001`) and ensure it binds to `0.0.0.0`.
2. Connect phone via USB and enable USB debugging.
3. From `mobile_app`, run:

```powershell
.\scripts\usb_dev.ps1
```

If you need a specific port:

```powershell
.\scripts\usb_dev.ps1 -Port 4001
```

## Run On Physical Android (Same Wi-Fi)

If you prefer Wi-Fi instead of USB, set `API_BASE_URL` to your PC LAN IP.

1. Start backend on your PC (preferred port `4000`; fallback may be `4001`) and ensure it binds to `0.0.0.0`.
2. Connect phone and PC to the same Wi-Fi.
3. From `mobile_app`, run:

```powershell
.\scripts\wifi_dev.ps1
```

The script auto-switches to `4001` if `4000` is busy and backend is listening on `4001`.

If auto-detect picks the wrong IP, run:

```powershell
.\scripts\wifi_dev.ps1 -HostIp 192.168.1.20 -Port 4000
```

You can also run manually:

```powershell
flutter run --dart-define=API_BASE_URL=http://<YOUR_PC_WIFI_IP>:<BACKEND_PORT>
```

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
