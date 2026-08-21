# Budu domain

This document describes **what the app does with money and budgets**, as implemented. It is not a Flutter layer diagram.

Models: `lib/features/budget/models/`. Limits and default categories: `lib/core/constants.dart`.

---

## Core logic (read this first)

**What does it do?**
A signed-in user plans income and expense caps for a date range, records actual income and expense events against that plan, and sees whether spending is within the caps. A plan can be personal or shared with another person via email invite.

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

Personal plans live under `budgets/{uid}/…`. Household plans live under `shared_budgets/{id}` with an `users` list. Events sit in an `events` subcollection and point at a `budgetId`.

**What are the business rules?**
Invariants the rest of this file spells out:

- A budget is a period (`monthly` / `biweekly` / `custom`). Placeholders are not real budgets.
- Planned expenses are a two-level tree (main → sub → amount). Zero/empty nodes are dropped on save. Amounts round to 2 decimals.
- Expense events do not mutate the plan. Income events do (add/subtract `income`).
- Overlap, empty plan, and planned expenses > income are warnings, not hard blocks.
- Expense amount `≥ 0` and `≤ 99999`; category required; subcategory required if that category has subs; description `≤ 50` chars. Planned income, if set, `≥ 0` and `≤ 999999`.
- Max 25 main categories, 20 subs each, names `≤ 20` chars, no duplicates.
- Shared: invite `pending` → `accepted` (user added to `users`) or `declined`. `isShared` only when `users.length > 1`.
- Reminders (personal only): no budget this calendar month → warn; no next-month budget → warn only in the last 3 days of the month.
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
- `isShared` = `users != null && users.length > 1`. A newly created household budget with only the creator is **not** `isShared` until a second user is added.

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

On first Google sign-in, if `users/{uid}` is missing, the app writes `email`, `isPremium: false`, `isAdmin: false`, `createdAt`. Sign-in is Google only.

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

- The new range overlaps an existing personal or shared budget for that user (`startDate ≤ newEnd` and `endDate ≥ newStart`).
- Income is `0` and there are no planned expenses.
- Planned expenses exceed planned income.

Income on save: empty is allowed; if present it must parse as a number, be `≥ 0`, and be `≤ 999999`. Values above `999999` are rejected before the later “continue anyway” dialog (that dialog is unreachable).

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

- Plan document: `shared_budgets/{id}` with `users: [creator, …]`, `createdBy`, `name`.
- Invite: `invitations/{id}` with `status: pending`. The new-budget invite dialog stores the email lowercased; invite-to-existing trims but may not lowercase.
- Accept: one Firestore transaction — set invitation `accepted` and `arrayUnion` the user’s uid onto `users`.
- Decline: set `status: declined`.
- Events: `shared_budgets/{id}/events`, with `userId` of the author.
- Chatbot save is **personal only**.

---

## “Need a budget” reminders

Personal budgets only, keyed off `startDate` year/month:

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

- Available personal budgets: `isPlaceholder == false`, ordered by `startDate` descending. Streams often `limit(50)`.
- Personal in-memory edits debounce-save after **1 second**.
- `migrateBudgets` copies old monthly docs and their expense subcollections into the new paths and skips ids that already exist. Old data is left in place.

---

## Caveats (as implemented)

- `Budget.remaining` is planned leftover, not actual remaining cash.
- A household budget with one member is not `isShared`.
- The “continue with income &gt; 999999” dialog cannot run; `_validateIncome` already rejects that value.
- Event-save UI looks for a 75-character description error; the validator caps at 50.
- Category actuals can roll a default-mapped subcategory up to its **mapped parent**, even if `event.category` is a different main category.
- Invite-to-existing may store mixed-case emails while pending-invite queries use lowercase.
