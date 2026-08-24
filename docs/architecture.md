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

The one exception: an **income event** also changes the plan — it adds to `Budget.income` (delete subtracts, not below 0). Expense events never change planned amounts.

**How does it do that?**

1. Google sign-in. First login creates `users/{uid}`.
2. Create a budget for a period (default: current month), or copy a previous plan’s income and category tree. Chatbot can fill a personal plan by asking about housing, car, food, etc.
3. Optionally share: create a household budget, invite by email, accept/decline. Members log events on the same plan.
4. Log events (amount, date, category/subcategory, optional note) against a selected budget.
5. Summary/history: sum actual expenses per category and show progress vs planned caps.

Personal plans live under `budgets/{uid}/…`. Household plans live under `shared_budgets/{id}` with an `users` list. Events sit in an `events` subcollection and point at a `budgetId`. Budget/event/shared **providers** persist through repositories (`BudgetRepository`, `EventRepository`, `SharedBudgetRepository`), not `FirebaseFirestore.instance`.

**What are the business rules?**
Invariants the rest of this file spells out:

- A budget is a period (`monthly` / `biweekly` / `custom`). Placeholders are not real budgets.
- Planned expenses are a two-level tree (main → sub → amount). Zero/empty nodes are dropped on save. Amounts round to 2 decimals.
- Expense events do not mutate the plan. Income events do (add/subtract `income`).
- Overlap (same type only), empty plan, and planned expenses > income are warnings, not hard blocks. Personal and household plans for the same dates are allowed.
- Shared: invite `pending` → `accepted` (user added to `users`) or `declined`. `isShared` when `users` is non-empty. No member cap. Sequential periods copy `users` and name. Invitee must already have a user doc; invite is written only after the plan exists.
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

- Adding or deleting an **expense** event does **not** change planned category amounts or `income`.
- Adding an **income** event **adds** the amount to the budget’s `income`.
- Deleting an income event **subtracts** from `income`, clamped at `0`.

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
- Plan document: `shared_budgets/{id}` with `users: [creator, …]`, `createdBy`, `name`. No member cap.
- Sequential create copies the previous period’s income/tree, name, and full `users` list, then advances the dates.
- Invite only after the plan exists. Invitee must already have `users/{uid}` (email lookup is trim + lowercase). Reject: empty, self, already a member, duplicate pending for that plan. Pending emails are queued on create and written after save.
- Invite: `invitations/{id}` with `status: pending`. Invitee email is stored trimmed and lowercased.
- Accept: one Firestore transaction — set invitation `accepted` and `arrayUnion` the user’s uid onto `users`.
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
shared_budgets/{id}                   household plan + users[]
shared_budgets/{id}/events            household events
invitations/{id}

Legacy (still read; not deleted by migration):
budgets/{uid}/monthly_budgets/{year}_{month}
  └── expenses/
```

- Available personal budgets: `isPlaceholder == false`, ordered by `startDate` descending. Budget list streams often `limit(50)`.
- Events for the **selected** budget are loaded in full (no 50-event cap) so tracking totals are complete. History `loadHistoryExpenses` still caps at 50 events per personal collection / per household plan.
- Budget, event, and invitation **writes** store dates as ISO-8601 strings (`DateTime.toIso8601String()`). Reads still accept Firestore `Timestamp` (legacy shared updates / old invites). User/notification `createdAt` uses `FieldValue.serverTimestamp()` and is separate.
- Deleting a personal or shared budget also deletes its `events` (and personal legacy expenses).
- Personal in-memory edits debounce-save after **1 second**.

---

## Caveats (as implemented)

- `Budget.remaining` is planned leftover, not actual remaining cash.


- Description field `maxLength` is still 75 (UI U1); the validator and save-error routing use 50 characters.
- Category actuals can roll a default-mapped subcategory up to its **mapped parent**, even if `event.category` is a different main category.
