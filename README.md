# Budu

Flutter personal budgeting app (Finnish UI) with Firebase Auth + Firestore.

Plan income and category caps for a period → log real income/expense events → track spend against the plan. Personal plans or household-shared plans (email invite). Google sign-in only.

**Stack:** Flutter (Dart) · Provider · Firebase Auth / Firestore / Crashlytics · Google Sign-In

---

## Features

- **Plan vs actual** — budgets are plans; events are the ledger. Tracking compares them without rewriting the plan.
- **Personal & household budgets** — monthly, biweekly, or custom periods; share a household plan by email invite.
- **Guided onboarding** — chatbot builds a first personal plan from housing, transport, food, and similar answers.
- **Main shell** — edit plan, summary/tracking (incl. distribution chart), and event history.
- **In-app reminders** — banners for pending invites and missing current/next-month plans (no OS push).
- **Android APK updates** — checks public GitHub release metadata and installs outside the store.

![Summary](https://github.com/user-attachments/assets/20536cc3-de5b-4ed2-8070-718787359f74)
![Budget](https://github.com/user-attachments/assets/ecee11dd-059c-48cc-a37e-3b772783156a)

---

## Documentation

Deeper product and engineering docs live under [`docs/`](docs/):

| Doc | Use when |
| --- | --- |
| [`docs/overview.md`](docs/overview.md) | How the product works end to end |
| [`docs/architecture.md`](docs/architecture.md) | Modules, layers, Firestore paths |
| [`docs/domain.md`](docs/domain.md) | Money/budget rules as implemented |
| [`docs/tests.md`](docs/tests.md) | How to run tests and what they cover |

Contributor conventions: [`AGENTS.md`](AGENTS.md).

---

## Quick start

**Prerequisites:** Flutter (Dart SDK `^3.7.2`), Android SDK / emulator or device. Firebase project config for Android is already in `android/app/google-services.json`.

```powershell
flutter pub get
flutter run
flutter build apk --release
```

Optional platforms when configured: `flutter run -d windows`, `flutter build web`.

---

## Project layout

| Path | Role |
| --- | --- |
| `lib/main.dart` | App entry (`MultiProvider` + router) |
| `lib/features/` | Feature modules (auth, budget, chatbot, mainscreen, history, notification, update, account) |
| `lib/features/budget/domain/` | Pure money/period/tracking rules (unit-tested) |
| `lib/core/` | Theme, router, constants |
| `test/features/` | Domain and repository unit tests |
| `integration_test/` | Android device smoke tests |
| `version.txt` / `changelog.txt` | App version metadata for the updater |

Data flow: **UI → Provider → Repository → Firestore**.

---

## Tests

```powershell
flutter test
flutter analyze
.\tool\run_android_integration_tests.ps1   # needs a connected Android device
```

See [`docs/tests.md`](docs/tests.md) for coverage details. Unit tests do not boot real Firebase (`fake_cloud_firestore`).

---

## License

Proprietary — see [`LICENSE`](LICENSE). All rights reserved.
