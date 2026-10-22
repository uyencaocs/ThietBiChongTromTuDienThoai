# android_cam_client

A new Flutter project.

## LAN / Network Setup

The app calls the ASP.NET Core API at `kBaseApiUrl` in `lib/config.dart`
(default `http://192.168.0.41:5235`). Change it if your PC's LAN IP differs
(`ipconfig` → IPv4 Address).

1. The backend binds to `http://0.0.0.0:5235` (see `Backend/Properties/launchSettings.json`).
   Start it with `dotnet run --launch-profile http`.
2. Open port 5235 in Windows Firewall – run in an **Administrator** PowerShell:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\setup_firewall.ps1
   ```

   Verify: `Get-NetFirewallRule -DisplayName "SecurityCam API"`.
   Remove: `Remove-NetFirewallRule -DisplayName "SecurityCam API"`.
3. Make sure the phone and PC are on the same Wi‑Fi network.

## Discord Alerts

Set `kDiscordWebhookUrl` in `lib/config.dart`. Alerts are skipped while the
placeholder URL is in place. Interactive buttons ("Xác nhận người nhà",
"Báo động") are only rendered for application-owned webhooks; for a regular
channel webhook the alert is automatically re-sent as plain text.

## Known Faces

`assets/known_faces.json` holds household members' face embeddings. Faces are
matched via cosine similarity against `kFaceMatchThreshold` (`lib/config.dart`).
Embedding length must match the output of the face-embedding model used in
`_extractFaceEmbedding` (`lib/camera_screen.dart`).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
