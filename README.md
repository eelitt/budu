# Budu
A cross-platform budgeting app built with Flutter and Firebase.

**Project**
- **Name**: `budu` — a personal budgeting and expense-tracking mobile app.
- **Stack**: Flutter (Dart), Firebase (Auth, Firestore, Crashlytics), Cloud Functions (Node.js).

**Quick Start**
- **Prerequisites**: `Flutter` (Dart SDK compatible with `sdk: ^3.7.2`), `Node.js` (see `functions/package.json` - uses `node: 22`), and the `Firebase CLI`.
- **Get dependencies**: run `flutter pub get` from the project root.
- **Run on a device/emulator**:

```powershell
# Get Flutter dependencies
flutter pub get

# Run the app on the default device/emulator
flutter run

# Run specifically on Windows (when available)
flutter run -d windows

# Build release APK (Android)
flutter build apk --release

# Build for web
flutter build web
```

**Firebase & Local Setup**
- **Project config**: `android/app/google-services.json` is present for Android. For iOS add `GoogleService-Info.plist` into `ios/Runner` if you deploy to iOS.
- **Environment file**: the repo expects a `.env` file (listed in `pubspec.yaml`). Copy an example or add required keys to `.env` at the project root.
- **Emulators & Functions**: Cloud Functions live in the `functions/` directory. To run functions locally:

```powershell
cd functions
npm install
npm run serve     # runs Firebase emulators for functions
```

Use `npm run deploy` in `functions/` to deploy functions to Firebase: `npm run deploy`.

**Notable files & locations**
- **App entry**: `lib/main.dart` — Flutter app entry point.
- **Firebase options**: `lib/firebase_options.dart` — generated Firebase config helper.
- **Cloud Functions**: `functions/index.js` and `functions/package.json`.
- **Firebase config**: `firebase.json` — Firebase hosting/emulator/other config.
- **Version & changelog**: `version.txt` and `changelog.txt` at project root.

**Functionality**
- **User accounts & auth**: Sign up and sign in with Firebase Authentication (email/password and Google Sign-In are supported).
- **Real-time sync**: User data and transactions synchronize across devices using Cloud Firestore.
- **Transactions management**: Create, edit and delete income and expense entries with category, amount, date and optional notes.
- **Budgets & alerts**: Set budget limits per category and receive visual indicators when spending approaches or exceeds limits.
- **Recurring transactions**: Schedule repeating transactions (monthly, weekly, daily) to automate recurring income or expenses.
- **Reports & visualizations**: View spending breakdowns and trends with charts (pie, line, bar) powered by charting libraries.
- **Categories & tags**: Organize transactions with categories and tags for easier filtering and reporting.
- **Attachments & receipts**: Attach receipts or files to transactions and open them with installed apps when needed.
- **Export / import**: Export transaction data (CSV/other formats) for backup or external analysis and import supported formats.
- **Offline support & connectivity**: Local caching and sync behavior when connectivity is restored (uses connectivity checks and local storage).
- **Crash reporting**: Crashlytics integration captures and reports crashes for improved stability.
- **Optional features**: In-app chat/support UI and other real-time messaging features may be available if implemented (see `flutter_chat_ui` and `flutter_chat_types` dependencies).
- **Server-side processing**: Background tasks, notifications or server logic can run in the `functions/` Cloud Functions code.

**Development notes**
- **Lint & tests**: standard `flutter test` and `flutter analyze` apply. There are no unit tests required to run the app, but `test/widget_test.dart` exists as a sample.
- **Assets**: images and splash icon are under `lib/assets/images/` and are referenced in `pubspec.yaml`.
- **Platform-specific**: Android build config is in `android/`. Use Android Studio or the CLI to sign and build release artifacts.

**Contributing**
- **How to help**: submit issues, open PRs with clear descriptions, and follow existing code style (see `analysis_options.yaml` and `flutter_lints` in `dev_dependencies`).
- **Local changes to environment**: do not commit secrets to the repository. Keep any API keys or credentials in the local `.env` and excluded files.

**License & Contact**
- Check repository.

---

