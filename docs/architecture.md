# Budu architecture

Stable system map: what the app is, where code lives, how data flows, and constraints that change slowly. Money/budget rules: [`domain.md`](domain.md). Human ground-up tour: [`overview.md`](overview.md). Tests: [`tests.md`](tests.md).

---

## What it is

Flutter personal budgeting app (Finnish UI). A signed-in user plans income and expense caps for a period, logs actual income/expense events, and compares spend to the plan. Plans are personal or household-shared (email invite). Google sign-in only. Backend: Firebase Auth + Firestore. Android APK updates via public GitHub release metadata (not store updates).

---

## Stack and layers

| Layer | Role |
| --- | --- |
| UI (screens / widgets) | Presentation; Finnish copy; navigation |
| Providers (`provider`) | App state; call repositories/services |
| Domain (`lib/features/*/domain/`) | Pure rules and decisions (prefer tests here) |
| Data (repositories) | Firestore (and auth) I/O |
| Models | Parse/serialize documents |

**Data flow:** UI → Provider → Repository → Firestore. Budget/event/shared providers must persist through `BudgetRepository`, `EventRepository`, `SharedBudgetRepository` — not `FirebaseFirestore.instance` from UI/providers for those writes.

Feature-based folders under `lib/features/`. Shared app pieces under `lib/core/` (router, theme, constants). Entry: `lib/main.dart` (`MultiProvider` + `AppRouter`).

---

## Features (where things live)

| Feature | Path | Owns |
| --- | --- | --- |
| Auth | `lib/features/auth/` | Google sign-in, session state, user profile doc, login bootstrap / destination |
| Budget | `lib/features/budget/` | Plans, events, create/edit, summary/tracking, shared household data, domain money rules |
| Chatbot | `lib/features/chatbot/` | First-run personal plan questionnaire (personal save only) |
| Main screen | `lib/features/mainscreen/` | Signed-in shell: tabs, chrome, menu actions, coverage banner triggers |
| History | `lib/features/history/` | Event list / filters for periods |
| Notification | `lib/features/notification/` | In-app banners only (no OS push; not persisted) |
| Account | `lib/features/account/` | Account settings UI |
| Update | `lib/features/update/` | Android APK check/download/install handoff |

Domain money math and validation: `lib/features/budget/domain/`. Models: `lib/features/budget/models/`. Default categories and limits: `lib/core/constants.dart`.

---

## Session and navigation

1. App starts at login. `LoginStartupCoordinator` starts auth init without waiting for the update check; update check runs in parallel and can still block leaving login.
2. Google sign-in; first login ensures `users/{uid}` (`UserProfileRepository`).
3. `SessionBootstrapService` + `decideLoginDestination`: no personal and no shared → chatbot; shared only → main (no personal preload); any personal → main (preload newest personal budget + events).
4. Signed-in UI is `MainScreen`: bottom nav `IndexedStack` — budget edit / summary (tracking) / history. Full-screen flows (create budget, settings) push on the root navigator.

Details: [`login_rework.md`](login_rework.md), [`mainscreen_rework.md`](mainscreen_rework.md).

---

## Persistence map

```
users/{uid}
budgets/{uid}/budgets/{budgetId}      personal plan
budgets/{uid}/events                  personal events (filter by budgetId)
households/{id}                       name + members[]
shared_budgets/{id}                   period plan + householdId + users[] copy
shared_budgets/{id}/events            household events
invitations/{id}

Legacy (still read; not deleted by migration):
budgets/{uid}/monthly_budgets/{year}_{month}
  └── expenses/
```

- Budget / event / invitation **writes** use ISO-8601 date strings; reads still accept Firestore `Timestamp`.
- User `createdAt` uses `FieldValue.serverTimestamp()` (separate from budget/event dates).
- In-app banners are **not** written to Firestore. Legacy `users/{uid}/notifications/{id}` may still exist in rules/old data; client does not use it. See [`firebase_rules.md`](firebase_rules.md).
- Deleting a personal or shared budget also deletes its events (and personal legacy expenses).
- Selected-budget events load uncapped into `ExpenseProvider.expenses` (Summary/tracking). History uses a separate `historyExpenses` list so multi-period browse does not overwrite tracking. Deep dives: [`summary_rework.md`](summary_rework.md), [`history_rework.md`](history_rework.md).
- Named `/history` remains a deep-link stub (`HistoryScreen(isActive: true)`); the signed-in shell embeds History in the bottom-nav `IndexedStack` and loads on first tab activation.
- Budget list streams often `limit(50)`.

Money-facing persistence behavior (debounce, overlap lists, etc.): [`domain.md`](domain.md).

---

## Cross-cutting constraints

- **Plan vs actual must not be mixed.** Events never mutate planned amounts. `Budget.remaining` is planned leftover, not cash after spending. Full rules: [`domain.md`](domain.md).
- Pure domain logic belongs in `domain/` modules and unit tests; do not bury new business rules only in widgets.
- Personal and household are separate stacks (collections + providers) that share domain concepts.
- In-app notification priority: pending invites → personal reminder → shared reminder; max **2** banners. Reminder **rules** (when to warn): [`domain.md`](domain.md). Banner mechanics: [`notifications_rework.md`](notifications_rework.md).
- Updater: public `version.txt` + GitHub latest release APK; no token. Deep dive: [`updater_rework.md`](updater_rework.md).
- Split a file when it grows past ~500–600 lines.

---

## Doc map

| Doc | Use when |
| --- | --- |
| [`architecture.md`](architecture.md) | Orienting; finding modules; data flow; slow-changing constraints |
| [`domain.md`](domain.md) | Changing budgets, events, tracking, shared, chatbot amounts, reminders |
| [`overview.md`](overview.md) | Learning how the product works end to end (human) |
| [`tests.md`](tests.md) | Running tests; what is covered |
| `*_rework.md` | Feature as-implemented deep dives and staged cleanup history |
| [`create-budget_rework.md`](create-budget_rework.md) | Create personal/household plan form, period defaults, save/invite dialogs |
| [`designthoughts.md`](designthoughts.md) | Opinion / product friction — not a behavior spec |
| [`firebase_rules.md`](firebase_rules.md) | Security rules notes |

When behavior changes, update the matching doc in the same change (see `AGENTS.md`).
