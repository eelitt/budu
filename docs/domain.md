# Budu domain

**What the app does with money and budgets**, as implemented. System map and modules: [`architecture.md`](architecture.md). Human tour: [`overview.md`](overview.md).

Models: `lib/features/budget/models/`. Pure rules: `lib/features/budget/domain/`. Limits and default categories: `lib/core/constants.dart`.

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

Personal plans: `budgets/{uid}/…`. Households: `households/{id}`; periods: `shared_budgets/{id}` with `householdId` and denormalized `users`. Events in an `events` subcollection, keyed by `budgetId`. Paths: [`architecture.md`](architecture.md#persistence-map).

**What are the business rules?**

- A budget is a period (`monthly` / `biweekly` / `custom`). Placeholders are not real budgets.
- Planned expenses are a two-level tree (main → sub → amount). Zero/empty nodes are dropped on save. Amounts round to 2 decimals.
- Expense and income events do not mutate the plan.
- Overlap (same type only), empty plan, and planned expenses > income are warnings, not hard blocks. Personal and household plans for the same dates are allowed.
- Shared: household owns periods; invite `pending` → `accepted` or `declined`. Sequential periods reuse `householdId`. Invitee must already have a user doc; invite only after the household/plan exists.
- Expense amount `≥ 0` and `≤ 99999`; category required; subcategory required if that category has subs; description `≤ 50` chars. Planned income, if set, `≥ 0` and `≤ 999999`.
- Max 25 main categories, 20 subs each, names `≤ 20` chars, no duplicates.
- Reminders are **separate** for personal and shared. Chatbot save is personal only; login skips chatbot if the user already has a shared budget.
- Chatbot: 2-week answers stored as monthly/2; yearly answers stored as /12.

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
- `remaining` = `income - totalExpenses` (**planned leftover**, not cash after actual spending).
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

Links an invitee email to a household / shared plan.

- Status: `pending` → `accepted` or `declined`.
- Lookups of pending invites trim and lowercase the signed-in user’s email.

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
- **Progress** = `actual / planned`. If planned is `0` and actual is `0`, progress is `0`; if planned is `0` and actual &gt; `0`, it counts as over budget.
- Over budget when actual &gt; planned, or when planned is `0` and actual &gt; `0`.
- Remaining percentage is clamped to `0–100`. Unused empty plan (planned `0`, actual `0`) shows 100% left; planned `0` with any spend shows 0% left.
- Pie chart (“Menojen jakautuminen”) uses **expense events only** (income excluded). **Muut** lumps main categories whose actual share is **&lt; 5%** of total actual expenses.
- Tracking footer **Yhteensä** is all actual expenses for the loaded period vs planned category total. Spend in categories outside the plan is included in that actual total and called out as **Suunnittelemattomat** when non-zero.
- Summary **Yhteenveto** card (`buildBudgetPeriodSummary`): planned vs actual income (separate), planned vs actual expenses, plan leftover (`plannedIncome − plannedExpenses`), actual leftover (`actualIncome − actualExpenses`), plan-used progress, overspent categories (including planned-0 + spend and unplanned categories), and unplanned expense total. Income events never change planned income.

---

## Categories

Built-in tree: `Constants.categoryMapping` in `lib/core/constants.dart` (Finnish main → default subcategories). Users may add custom main and subcategory names.

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

Personal and shared are evaluated **independently** with the same rule on their own `startDate` lists:



1. If no budget of that kind starts in the **current** calendar month → warn and offer create (personal → create personal; shared → create household).
2. Else if no budget of that kind starts in the **next** month → warn only when **≤ 3 days** remain in the current month.

Both reminders can show at once when both kinds are missing (subject to the in-app banner max of 2; pending invites outrank reminders). Banner UI: [`notifications_rework.md`](notifications_rework.md).

---

## Chatbot amounts that become a budget

- Period: month vs 2-week. For a 2-week budget, numeric answers (except the yes/no and type questions) are stored as `value / 2`.
- Yearly answers stored as `value / 12`: home insurance, property tax, car insurance, vehicle tax, car maintenance.

---

## Persistence behavior (money-facing)

- Available personal budgets: `isPlaceholder == false`, ordered by `startDate` descending.
- Events for the **selected** budget are loaded in full (no event cap) so tracking totals are complete (`ExpenseProvider.expenses`). History loads every event for each listed period into a **separate** list (`historyExpenses`) so browse loads do not overwrite Summary/tracking.
- Summary owns loading events for the currently selected budget; tracking, distribution, and event views consume that state and do not start duplicate loads. Overlapping loads: only the newest request may replace in-memory events.
- The create-budget screen reuses one budget-list request for its lifetime (refresh only on an explicit new screen flow).
- Personal in-memory edits debounce-save after **1 second**.

Collection paths and date encoding: [`architecture.md`](architecture.md#persistence-map).

---

## Caveats (as implemented)

- `Budget.remaining` is planned leftover, not actual remaining cash.
- Description field `maxLength` is still 75 (UI); the validator and save-error routing use 50 characters.
- Category actuals can roll a default-mapped subcategory up to its **mapped parent**, even if `event.category` is a different main category.
