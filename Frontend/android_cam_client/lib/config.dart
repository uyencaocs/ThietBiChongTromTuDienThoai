/// Configuration constants for the application.
///
/// Base API URL – used by the client to communicate with the backend.
/// When running on a real device, replace the placeholder with the LAN IP
/// of the server (e.g., 192.168.0.41).
const String kBaseApiUrl = 'http://192.168.0.41:5235';

/// Discord webhook placeholder. Replace `YOUR_WEBHOOK_ID` and
/// `YOUR_WEBHOOK_TOKEN` with the actual values after creating the webhook.
const String kDiscordWebhookUrl =
    'https://192.168.0.41:45455/swagger/index.html';

/// Cosine-similarity threshold for face matching. A live face whose best
/// similarity against `assets/known_faces.json` is >= this value is treated
/// as "Người nhà"; otherwise it is "Người lạ". Range: -1.0 .. 1.0.
const double kFaceMatchThreshold = 0.80;
