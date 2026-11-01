/// Build-time switches.
///
/// Firebase is ON by default (the project is configured via `flutterfire
/// configure`, google-services.json and GoogleService-Info.plist). To run the
/// game fully offline (guest + local leaderboard) use:
///
///   flutter run --dart-define=USE_FIREBASE=false
const bool useFirebase = bool.fromEnvironment('USE_FIREBASE', defaultValue: true);

/// Where the `docs/` folder is published (GitHub Pages). No trailing slash.
/// Override per build with `--dart-define=LEGAL_BASE_URL=https://...`.
const String legalBaseUrl = String.fromEnvironment(
  'LEGAL_BASE_URL',
  defaultValue: 'https://YOUR-GITHUB-USERNAME.github.io/gearspin',
);

/// Contact address shown in the privacy policy / used for deletion requests.
const String supportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: 'YOUR-EMAIL@example.com',
);
