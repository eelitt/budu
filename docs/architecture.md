# Budu domain

This document describes **what the app does with money and budgets**, as implemented. It is not a Flutter layer diagram.

Models: `lib/features/budget/models/`. Limits and default categories: `lib/core/constants.dart`.

---

## Core logic (read this first)

**What does it do?**
A signed-in user plans income and expense caps for a date range, records actual income and expense events against that plan, and sees whether spending is within the caps. A plan can be personal or a household plan shared with other people via email invite.

**What is the core logic?**
Two layers of money that must not be mixed:

1. **Plan** — a `Budget`: planned income and planned amounts per category/subcategory for a period.
2. **Actual** — `Event`s: what was recorded.

Tracking is the comparison of actual expense totals to planned caps. `Budget.remaining` is planned leftover (`income − planned expenses`), not cash after actual spending.

Income events and expense events never change planned amounts. Planned income is only edited on the plan (create/edit / budget-tab income field).

**How does it do that?**

1. Google sign-in. First login creates `users/{uid}`.
2. Create a budget for a period (default: current month), or copy a previous plan’s income and category tree. Chatbot can fill a personal plan by asking about housing, car, food, etc.
3. Optionally share: create a household budget, invite by email, accept/decline. Members log events on the same plan.
4. Log events (amount, date, category/subcategory, optional note) against a selected budget.
5. Summary/history: sum actual expenses per category and show progress vs planned caps.

Personal plans live under `budgets/{uid}/…`. Households live under `households/{id}`; periods under `shared_budgets/{id}` with `householdId` and a denormalized `users` list. Events sit in an `events` subcollection and point at a `budgetId`. Budget/event/shared **providers** persist through repositories (`BudgetRepository`, `EventRepository`, `SharedBudgetRepository`), not `FirebaseFirestore.instance`.

**What are the business rules?**
Invariants the rest of this file spells out:

- A budget is a period (`monthly` / `biweekly` / `custom`). Placeholders are not real budgets.
- Planned expenses are a two-level tree (main → sub → amount). Zero/empty nodes are dropped on save. Amounts round to 2 decimals.
- Expense and income events do not mutate the plan.
- Overlap (same type only), empty plan, and planned expenses > income are warnings, not hard blocks. Personal and household plans for the same dates are allowed.
- Shared: a **household** (`households/{id}`: name + members) owns periods (`shared_budgets` with `householdId`; `users` is a copy of members for queries). Invite `pending` → `accepted` (member added to the household and every period) or `declined`. Sequential periods reuse `householdId`. Invitee must already have a user doc; invite is written only after the household/plan exists.
- Expense amount `≥ 0` and `≤ 99999`; category required; subcategory required if that category has subs; description `≤ 50` chars. Planned income, if set, `≥ 0` and `≤ 999999`.
- Max 25 main categories, 20 subs each, names `≤ 20` chars, no duplicates.
- Reminders use personal **and** shared `startDate`s: no budget this calendar month → warn; no next-month budget → warn only in the last 3 days of the month. Chatbot save is personal only; login skips chatbot if the user already has a shared budget.
- Chatbot: 2-week answers stored as monthly/2; yearly answers stored as /12. Chatbot saves personal budgets only.

Details, formulas, category tree, Firestore paths, and as-implemented caveats follow.

---

## Domain objects

### Budget

| Field | Meaning |
| --- | --- |
| `income` | Planned income for the period |
| `expenses` | Planned amounts: `Map<mainCategory, Map<subcategory, amount>>` |
| `startDate` / `endDate` | Inclusive period |
| `type` | `monthly`, `biweekly`, or `custom` |
| `isPlaceholder` | Not a real budget; excluded from available lists |
| `id` | Document id |
| `sharedBudgetId`, `users`, `createdBy`, `name` | Shared-household fields (optional) |

Derived:

- `totalExpenses` = sum of every planned subcategory amount.
- `remaining` = `income - totalExpenses`. This is **planned leftover**, not cash after actual spending.
- `isShared` = `users != null && users.isNotEmpty` (a household plan with only the creator is already shared).

Legacy documents that store `year` + `month` instead of dates are parsed as a calendar month with `type = monthly`.

### Event (`ExpenseEvent`)

| Field | Meaning |
| --- | --- |
| `type` | `income` or `expense` |
| `amount` | Euros |
| `createdAt` | Event date |
| `category` | Main category; income events use `"Tulo"` |
| `subcategory` | Optional; expenses only |
| `budgetId` | Budget this event belongs to |
| `description` | Optional |
| `userId` | Who added it (set on shared-budget events) |

### Invitation

Links an invitee email to a `sharedBudgetId`.

- Status: `pending` → `accepted` or `declined`.
- Lookups of pending invites trim and lowercase the signed-in user’s email.

### User

On first Google sign-in, `UserProfileRepository.ensureUserDocument` creates `users/{uid}` if missing (`email`, `isPremium: false`, `isAdmin: false`, `createdAt`). Sign-in is Google only (`AuthRepository`). Profile reads go through the same repository (`UserProvider`).

---

## Planned vs actual

| Layer | Stored on | Role |
| --- | --- | --- |
| Planned | Budget `income` and `expenses` | Caps the user set for the period |
| Actual | Events | What was recorded |

- Adding or deleting an **expense** or **income** event does **not** change planned category amounts or planned `income`.

On budget save, amounts are rounded to 2 decimal places. Subcategories with amount `≤ 0` are omitted; main categories with no remaining subcategories are omitted.

Display format: `X.XX €`.

---

## Periods

- **Create-budget default** (no source budget): current calendar month, first day through last day, `type = monthly`.
- **monthly**: first day of a month → last day of that month.
- **biweekly**: `endDate = startDate + 13 days` (14-day window).
- **custom**: whatever range the user picked.
- **Chatbot**, if any personal budget already exists: next period starts the day after the latest `endDate`. Otherwise the current month (or current start + 13 days if biweekly).

Copying a budget into a new period copies planned income and the category/subcategory tree.

Creating from scratch seeds empty main categories from `categoryMapping` (no subcategories until the user adds them). Creating from an existing budget copies its amounts.

---

## Save warnings (not hard blocks)

The user can continue after confirming:

- The new range overlaps another plan of the **same kind** (personal vs personal, or household vs household). Personal and household for the same dates do not warn. Editing skips the budget being saved. A failed overlap load does not count as “no overlap”.
- Income is `0` and there are no planned expenses.
- Planned expenses exceed planned income.

Income on save: empty is allowed; if present it must parse as a number, be `≥ 0`, and be `≤ 999999`. Values above `999999` are a hard reject (`validateIncomeText`), not a continue-dialog.

---

## Tracking

For a selected budget:

- **Category planned** = sum of its planned subcategory amounts.
- **Category actual** = sum of expense events mapped to that main category:
  - If the event’s `subcategory` is in the default `categoryMapping`, it rolls up to that mapping’s parent.
  - Otherwise it uses `event.category`.
- **Subcategory actual** = expense events with matching `budgetId`, `category`, and `subcategory`.
- **Progress** = `actual / planned` (`0` if planned is `0`). Over budget when `progress > 1`.
- Remaining percentage is clamped to `0–100` (overspend still shows 0% left).
- Pie chart **Muut**: main categories whose planned share is **&lt; 5%** of total planned expenses are lumped together.

---

## Categories

Built-in tree (`Constants.categoryMapping`):

| Main | Default subcategories |
| --- | --- |
| Asuminen | Vuokra, Asuntolaina, Kiinteistövero, Jätehuolto, Yhtiövastike |
| Liikkuminen | Auton rahoitus, Autopaikan vuokra, Polttoaine, auton verot, Auton ylläpito, Julkiset |
| Laskut ja palvelut | Sähkö, Puhelinlasku, Nettiliittymä, Vesi |
| Vakuutukset | Kotivakuutus, Autovakuutus, Henkilövakuutus, Matkavakuutus, Lemmikkivakuutus |
| Viihde | Viihdekulut, Suoratoistopalvelut, Elokuvat ja teatteri, Pelit, Kirjat ja lehdet, Konsertit, Tapahtumat |
| Harrastukset | Harrastuskulut, Urheiluvälineet, Jäsenmaksut, Tapahtumat, Tarvikkeet |
| Ruoka | Ruokakauppa, Ravintolat, Kahvilat, Takeaway |
| Terveys | Terveyskulut, Lääkärikäynnit, Lääkkeet, Terapia, Hammaslääkäri, Silmälääkäri |
| Hygienia | Hygieniakulut, Kosmetiikka, Siivous |
| Lemmikit | Lemmikkikulut, Ruoka, Lääkärikäynnit, Tarvikkeet, Hoito |
| Sijoittaminen ja säästäminen | Säästäminen, Sijoittaminen, Hätärahasto, Osakkeet, Rahastot, Kryptovaluutat |
| Velat | Velat, Luottokortti, Lainat, Korot, Opintolaina, Asuntolainan korot, osa-maksut |

Users may add custom main and subcategory names.

Limits:

- Max **25** main categories.
- Max **20** subcategories per main category.
- Name max **20** characters.
- Duplicate names rejected.

---

## Event validation

- Amount must parse as a number and be `≥ 0`.
- Expense amount max **99999**.
- Expense requires a category. If that category already has subcategories, a subcategory is required.
- Description max **50** characters.
- User must be signed in and a budget selected.

---

## Shared household

- Created from the same form as a personal plan, plus a **required name** and optional email invites.
- Household document: `households/{id}` with `name`, `members`, `createdBy`.
- Plan document: `shared_budgets/{id}` with `householdId`, denormalized `users` (copy of members), `createdBy`, `name`. No member cap.
- Periods without `householdId` are grouped on fetch (`createdBy` + name + sorted `users`) onto a new household.
- Sequential create reuses `householdId`; members and name come from the household.
- Invite only after the household exists. Invitee must already have `users/{uid}`. Reject: empty, self, already a member, duplicate pending for that household.
- Invite: `invitations/{id}` with `householdId`, `status: pending`. Email trimmed and lowercased.
- Accept: invitation `accepted`, `arrayUnion` uid onto household `members` and every period’s `users` with that `householdId`.
- Decline: set `status: declined`.
- Events: `shared_budgets/{id}/events`, with `userId` of the author.
- Chatbot save is **personal only**.

---

## “Need a budget” reminders

Personal **and** shared `startDate` year/month:

1. If no budget starts in the **current** calendar month → warn and offer create.
2. Else if no budget starts in the **next** month → warn only when **≤ 3 days** remain in the current month.

---

## Chatbot amounts that become a budget

- Period: month vs 2-week. For a 2-week budget, numeric answers (except the yes/no and type questions) are stored as `value / 2`.
- Yearly answers stored as `value / 12`: home insurance, property tax, car insurance, vehicle tax, car maintenance.

---

## Persistence

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

- Available personal budgets: `isPlaceholder == false`, ordered by `startDate` descending. Budget list streams often `limit(50)`.
- Events for the **selected** budget are loaded in full (no 50-event cap) so tracking totals are complete. History loads every event for each period in the current list (same uncapped path).
- Summary owns loading events for the currently selected budget; tracking, distribution, and event views consume the resulting provider state and do not initiate duplicate loads. The initial load passes the personal/shared storage path explicitly.
- If multiple selected-budget loads overlap, only the newest request may replace the provider’s in-memory events. A slower result from an older selection is ignored.
- The create-budget screen reuses one budget-list request for its lifetime instead of starting a new budget-list read on every rebuild. The request is refreshed only by an explicit new screen flow.
- Budget, event, and invitation **writes** store dates as ISO-8601 strings (`DateTime.toIso8601String()`). Reads still accept Firestore `Timestamp` (legacy shared updates / old invites). User/notification `createdAt` uses `FieldValue.serverTimestamp()` and is separate.
- Deleting a personal or shared budget also deletes its `events` (and personal legacy expenses).
- Personal in-memory edits debounce-save after **1 second**.

---

## Application updater

The updater runs from the login flow and can also be started from the main-screen developer menu. It supports Android APK updates; it does not update the application through an app store.

### Current flow

1. `LoginScreen` creates an `UpdateManager` and starts `checkAndHandleUpdate` during initialization.
2. `UpdateManager` asks `UpdateHandler` to perform the check through `UpdateService`.
3. `UpdateService` reads the public version file at `https://raw.githubusercontent.com/eelitt/budu/main/version.txt` and compares it with the installed package version. It returns this result as typed `UpdateInfo` data.
4. If the version is newer, `UpdateService` requests `https://api.github.com/repos/eelitt/budu/releases/latest`, selects the first `.apk` asset, and returns its public `browser_download_url`. A newer version without an APK is represented separately from an available downloadable update.
6. `UpdateHandler` checks Android install permission and network connectivity, then presents the update confirmation dialog.
7. After confirmation, `UpdateManager` creates one broadcast download stream per attempt. The progress dialog and completion handling consume that same stream, so the APK is downloaded only once. `UpdateService` streams the file into the platform temporary directory and calls `OpenFile.open` to hand it to Android's package installer.
8. On a successful install handoff, `UpdateHandler` stores `isUpdated` and `updatedVersion` in `SharedPreferences` and clears its required-update state.

The developer-menu changelog path uses the public GitHub Contents API at `https://api.github.com/repos/eelitt/budu/contents/changelog.txt` and requests the raw file contents. No GitHub token or bundled `.env` configuration is used by the updater.

### Updater state and caveats

- `UpdateService` owns version lookup, GitHub requests, APK download, temporary-file storage, and opening the APK. Public metadata requests have timeouts and validate version/release responses.
- `UpdateHandler` owns the update result, install permission, connectivity, download state, and update persistence.
- `UpdateManager` coordinates dialogs and the download flow. It shares one broadcast download stream between progress rendering and completion handling.
- `MainScreenUpdateDialogService` contains a separate manual/debug update-check path.
- The current release API response must contain at least one `.apk` asset. A newer `version.txt` without an APK asset produces no downloadable update.
- Update requests are unauthenticated because the repository and release metadata are public. The APK download uses the asset's `browser_download_url`.
- The updater implementation and planned simplification are documented in [`updater_rework.md`](updater_rework.md).

---

## Caveats (as implemented)

- `Budget.remaining` is planned leftover, not actual remaining cash.


- Description field `maxLength` is still 75 (UI U1); the validator and save-error routing use 50 characters.
- Category actuals can roll a default-mapped subcategory up to its **mapped parent**, even if `event.category` is a different main category.
