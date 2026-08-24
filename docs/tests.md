# Tests

Domain spec: [`architecture.md`](architecture.md). Tests encode **current** behavior, including caveats. They do not boot the real Firebase app.

## How to run

From the repo root:

```powershell
flutter test
```

All cases live under `test/features/budget/`. There is no widget test that pumps `MyApp` (that would initialize Firebase).

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
| ISO date writes + Timestamp reads | `date_encoding_test.dart` |
| `NotificationProvider.markAsRead` | `test/features/notification/notification_mark_as_read_test.dart` |
| `UserProfileRepository` | `test/features/auth/user_profile_repository_test.dart` |

Repositories are constructed with `FakeFirebaseFirestore` (`fake_cloud_firestore` dev dependency). Use `BudgetModel.parse` / `ExpenseEvent.parse` in unit tests, not `fromMap` — `fromMap` logs Crashlytics on failure.

Date-dependent rules take `now`. Production callers pass `DateTime.now()`.

## What each file covers

**Money** — round to 2 decimals; planned totals and remaining (can be negative); `isShared` when `users` is non-empty; drop ≤0 sub-amounts and empty mains on sanitize; income add; income subtract clamped at 0; `BudgetModel.copy()` does not share nested maps.

**Periods** — calendar month range (Feb leap/non-leap, December); next month wrapping year; days left in month; overlap (same day and shared endpoint overlap; adjacent days do not); `hasOverlappingBudgetPeriod` uses the list the saver passes (personal-only or household-only) and ignores `excludeId` (edit); next period after latest end (monthly vs +13 days biweekly).

**Reminders** — no budget whose `startDate` is in the current month → `missingCurrentMonth`; else no next-month start and ≤3 days left → `missingNextMonth`; otherwise `none`. A start mid-month still counts as that month.

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

**Notifications** — after `initializeNotifications(uid)`, `markAsRead` updates `users/{uid}/notifications/{id}` (`read: true`). It does not write under a placeholder user id. Before initialize, `markAsRead` is a no-op.

**Events for one budget** — `EventRepository.getEventsForBudget` returns every matching event (no 50-event cap). Extra `budgetId`s are excluded. Shared path uses `shared_budgets/{id}/events`. Empty personal `events` falls back to legacy `monthly_budgets/.../expenses`. Tracking totals on the loaded list include all of those expenses. `saveEvent` / `deleteEvent` write that same `events` collection. History `getRecentPersonalEvents` is still capped at 50.

**Income field** — `BudgetRepository.updateIncome` updates `income` on `budgets/{uid}/budgets/{id}`.

## Adding a test

1. Put the rule in `lib/features/budget/domain/` (no `BuildContext`, Provider, Firestore, Crashlytics).
2. Add a case next to the matching file under `test/features/budget/`.
3. Freeze dates. Do not pump `MyApp`.
4. For Firestore, inject `FakeFirebaseFirestore` into the repository constructor.
5. `flutter test`.

If the code today is surprising, test that surprise and mention it in `architecture.md` caveats. Do not “fix” a caveat in the same change as extracting it unless that is the task.

## Not covered here

Widget trees, Google sign-in, Crashlytics, auto-update, chatbot question copy/routing, theme, Cloud Functions stub. Persistence tests use the fake only; they do not hit a real project or emulator.
