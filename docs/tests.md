# Tests

Domain spec: [`domain.md`](domain.md). System map: [`architecture.md`](architecture.md). Tests encode **current** behavior, including caveats. They do not boot the real Firebase app.

## How to run

From the repo root:

```powershell
flutter test
```

Android integration tests require a connected Android device. The runner refuses to start when Flutter reports no Android device:

```powershell
.\tool\run_android_integration_tests.ps1
```

Run only updater or login smoke:

```powershell
.\tool\run_android_integration_tests.ps1 -Target updater
.\tool\run_android_integration_tests.ps1 -Target login
```

To select a specific connected device:

```powershell
.\tool\run_android_integration_tests.ps1 -DeviceId <device-id>
```

Unit cases live under `test/features/`; most domain cases are under `test/features/budget/`. Device integration cases live under `integration_test/` and are not run by the normal `flutter test` command. There is no regular widget test that pumps `MyApp` because that would initialize Firebase; the Android integration tests initialize Firebase explicitly.

## Layout

Production rules sit in `lib/features/budget/domain/`. Tests call those functions (and model `parse` helpers) with frozen `DateTime` values.

| Production | Tests |
| --- | --- |
| `domain/periods.dart` | `periods_test.dart` |
| `domain/reminder_rules.dart` | `reminder_rules_test.dart` |
| `domain/money.dart` | `money_test.dart` |
| `domain/tracking.dart` | `tracking_test.dart` |
| `domain/event_rules.dart` | `event_rules_test.dart` |
| `domain/save_decisions.dart` | `save_decisions_test.dart` |
| `domain/shared_rules.dart` | `shared_rules_test.dart` |
| `domain/chatbot_amounts.dart` | `chatbot_amounts_test.dart` |
| `BudgetModel.parse` | `budget_model_parse_test.dart` |
| `ExpenseEvent.parse` | `expense_event_parse_test.dart` |
| `BudgetRepository` / `SharedBudgetRepository` | `budget_repository_test.dart` |
| `EventRepository` | `event_repository_test.dart` |
| `ExpenseProvider` stale-load protection; history vs summary list isolation | `expense_provider_test.dart` |
| History client filters | `test/features/history/history_filters_test.dart` |
| ISO date writes + Timestamp reads | `date_encoding_test.dart` |
| Banner kinds, max-2 priority, invite↔reminder isolation, Finnish invite copy | `test/features/notification/notification_banner_list_test.dart` |
| Main-screen add-event target + personal create month range | `test/features/mainscreen/main_screen_decisions_test.dart` |
| Main-screen chrome: bottom nav labels; create-budget menu vs next-month flag | `test/features/mainscreen/main_screen_chrome_test.dart` |
| `UserProfileRepository` | `test/features/auth/user_profile_repository_test.dart` |
| `AuthProvider` session transitions | `test/features/auth/auth_provider_test.dart` |
| `decideLoginDestination` | `test/features/auth/login_destination_test.dart` |
| `SessionBootstrapService` | `test/features/auth/session_bootstrap_service_test.dart` |
| `LoginStartupCoordinator` auth vs update gate | `test/features/auth/login_startup_coordinator_test.dart` |
| Android login session-readiness smoke | `integration_test/login_android_test.dart` |
| Updater result states, version comparison, metadata validation, and APK URL selection | `test/features/update/update_info_test.dart` |
| Updater download invocation | `test/features/update/update_handler_test.dart` |
| Android updater metadata smoke | `integration_test/updater_android_test.dart` |

Repositories are constructed with `FakeFirebaseFirestore` (`fake_cloud_firestore` dev dependency). Use `BudgetModel.parse` / `ExpenseEvent.parse` in unit tests, not `fromMap` — `fromMap` logs Crashlytics on failure.

Date-dependent rules take `now`. Production callers pass `DateTime.now()`.

## What each file covers

**Money** — round to 2 decimals; planned totals and remaining (can be negative); `isShared` when `users` is non-empty; drop ≤0 sub-amounts and empty mains on sanitize; income add; income subtract clamped at 0; `BudgetModel.copy()` does not share nested maps.

**Periods** — calendar month range (Feb leap/non-leap, December); next month wrapping year; days left in month; overlap (same day and shared endpoint overlap; adjacent days do not); `hasOverlappingBudgetPeriod` uses the list the saver passes (personal-only or household-only) and ignores `excludeId` (edit); next period after latest end (monthly vs +13 days biweekly).

**Reminders** — `reminderDecision` is pure: no budget whose `startDate` is in the current month → `missingCurrentMonth`; else no next-month start and ≤3 days left → `missingNextMonth`; otherwise `none`. A start mid-month still counts as that month. The UI runs it separately on personal and shared startDate lists.

**Tracking** — expense events only; default subcategory rolls up to the mapped parent even if `event.category` differs; custom sub uses `event.category`; subcategory totals filter `budgetId` + category + sub; progress 0 when planned is 0; remaining % clamped 0–100 (100 when planned is 0); pie **Muut** for &lt;5% of planned total.

**Events** — amount must parse and be ≥ 0; expense max 99999; expense needs category; subcategory required only if that category already has subs; description ≤ 50; must be logged in. Income does not need a category. `eventValidationField` maps the 50-character description message to the description field (not the old 75-character string).

**Save decisions** — income text: empty ok, else number ≥ 0 and ≤ 999999 (hard reject). Decision order: income error → overlap warning → empty plan → expenses &gt; income → ok. After confirm, `ignoreEmpty` / `ignoreOverspend` skip that step. There is no “continue with income too large” warning.

**Shared** — invite status `pending` / `accepted` / `declined`; only `pending` may go to accepted or declined; lookup email is trim + lowercase; `Invitation.toMap` writes that normalized email. `validateInvite` rejects empty, self, missing user, already member, duplicate pending. `householdUsersForNewPeriod` always includes the creator and copies previous members. Create invitation requires the plan doc; sequential create copies `users`.

**Delete** — `BudgetRepository.deleteBudget` removes the plan, matching `events`, and legacy expenses. `deleteSharedBudget` removes the shared plan and its events. Other `budgetId`s’ events stay.

**Chatbot amounts** — biweekly `/2`; yearly `/12`; both is `/2` then `/12` (same as the question processor).

**Date encoding** — `toMap` for budget, event, and invitation stores ISO-8601 strings (not `Timestamp`). `parse` / `fromMap` still accept `Timestamp` for old documents.

**Parse** — ISO dates; legacy `year`+`month` (budget becomes that calendar month, `type = monthly`; event `budgetId` becomes `"year_month"`); missing dates fall back to injected `now`; missing income/category/amount defaults; shared fields; `toMap` round-trip for a typical personal budget. Timestamp-typed Firestore dates are not covered in these unit tests (ISO path is).

**Repositories (fake Firestore)** — personal save/get; missing doc is null; read from legacy `monthly_budgets/{year}_{month}`; available list omits placeholders; accept invite `arrayUnion`s the user and sets status `accepted`; decline sets `declined`; pending invites match a normalized email.

**User profile** — `ensureUserDocument` creates `users/{uid}` once and does not overwrite `isAdmin`/email on a second call. Missing profile is null.

**Notifications** — in-memory kinds only (no Firestore). `syncPendingInvites` / reminder upserts feed `notifications` (priority invite > personal > shared, max 2). Removing invite leaves reminders; `clearReminders` leaves invites.

**Events for one budget** — `EventRepository.getEventsForBudget` returns every matching event (no 50-event cap). Extra `budgetId`s are excluded. Shared path uses `shared_budgets/{id}/events`. Empty personal `events` falls back to legacy `monthly_budgets/.../expenses`. Tracking totals on the loaded list include all of those expenses. `saveEvent` / `deleteEvent` write that same `events` collection. History `loadHistoryExpenses` uses that uncapped load per listed period into `historyExpenses` (does not overwrite Summary `expenses`).

**History filters** — `filterHistoryEvents` applies category / type / description query / budgetId; Finnish “Kaikki …” sentinels and null mean no filter; query is trimmed and case-insensitive.

**Android updater integration** — `integration_test/updater_android_test.dart` runs only through the device runner, which uses `flutter drive` and refuses to start without an Android device. It launches `MyApp`, reads the installed Android package version, and verifies the public GitHub update metadata contract. APK installation and system-settings permission flows still require manual device validation.

**Event loading races** — `ExpenseProvider.loadExpenses` and `loadHistoryExpenses` each ignore an older asynchronous result when a newer load of the same kind has started.

**Income events** — adding or deleting an income event does not change planned `Budget.income`.

**Income field** — `BudgetRepository.updateIncome` updates `income` on `budgets/{uid}/budgets/{id}`. `adjustIncome` loads, adds or subtracts (not below 0), and writes.

**Shared create** — `createSharedBudget` takes a `BudgetModel`; creates a household if `householdId` is missing; `users` always includes the creator. Sequential periods reuse `householdId`. `ensureHouseholds` groups old period docs. Accept invite adds the uid to the household and every period.

## Adding a test

1. Put the rule in `lib/features/budget/domain/` (no `BuildContext`, Provider, Firestore, Crashlytics).
2. Add a case next to the matching file under `test/features/budget/`.
3. Freeze dates. Do not pump `MyApp`.
4. For Firestore, inject `FakeFirebaseFirestore` into the repository constructor.
5. `flutter test`.

### Android updater integration

The Android test requires:

- a connected Android phone or emulator visible to `flutter devices --machine`
- USB debugging enabled and the device authorized
- a working Android build toolchain
- network access to the public GitHub endpoints

Run it only through the device runner:

```powershell
.\tool\run_android_integration_tests.ps1
```

The runner selects the first connected Android device. To select one explicitly:

```powershell
.\tool\run_android_integration_tests.ps1 -DeviceId <device-id>
```

The runner fails before starting Flutter when no Android device is available or when the requested device ID is not connected. Do not include `integration_test/updater_android_test.dart` in the normal `flutter test` command; Flutter treats the integration and unit test modes separately in this project.

The current integration test verifies app launch, Firebase initialization, installed-version lookup, and public update metadata. It does not perform a real APK installation, grant the unknown-apps permission, return from Android settings, or verify post-install `SharedPreferences` state.

If the code today is surprising, test that surprise and mention it in `domain.md` caveats. Do not “fix” a caveat in the same change as extracting it unless that is the task.

## Not covered here

Widget trees, Google sign-in, Crashlytics, full auto-update installation flow, chatbot question copy/routing, theme, and Cloud Functions stub. Unit persistence tests use the fake Firestore only; they do not hit a real project. The updater integration test is the exception: it runs on a connected Android device and reaches the public GitHub endpoints, but it still does not install a release APK.
