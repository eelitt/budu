# Budu overview

Human-oriented tour of how the app works from the ground up. For modules and data flow, see [`architecture.md`](architecture.md). For exact money rules, see [`domain.md`](domain.md).

---

## Product in one paragraph

Budu is a Flutter budgeting app aimed at Finnish users. After Google sign-in, you build a **plan** for a time period (planned income and category spending caps), then log **what actually happened** as income and expense events. The tracking screens compare those events to the plan. You can keep plans private or share a household plan with others by email invite.

---

## Mental model

Keep these two ideas separate:

1. **The plan (`Budget`)** — “I expect this income and these category caps for this date range.”
2. **The ledger (`Event`s)** — “This is what I recorded.”

Tracking answers: “Am I within the caps?” It does **not** rewrite the plan when you add an expense. Planned leftover (`Budget.remaining`) is income minus **planned** expenses, not cash left after real spending.

---

## User journey

### 1. Sign in

The app opens on the login screen. Sign-in is Google only. On first login the app creates a Firestore user profile. While login runs, an Android update check may also run in parallel; a required update can block leaving login.

### 2. First destination

After auth, the app looks at existing budgets:

| Situation | Where you go |
| --- | --- |
| No personal and no shared budgets | Chatbot (guided personal plan) |
| Only shared / household budgets | Main screen |
| Any personal budgets | Main screen (newest personal plan + its events preloaded) |

### 3. Main screen

The signed-in home is a shell with three tabs:

| Tab | Finnish label | Purpose |
| --- | --- | --- |
| Budget | Muokkaa budjettia | Edit the selected plan (income, categories) |
| Summary | Seuranta | Period overview (plan vs actual), progress vs caps, distribution, events |
| History | Historia | Browse logged events across periods |

Menus and banners live on the shell: add event, create personal or household budget, account settings, logout. In-app banners can show pending invites and “you need a budget for this/next month” reminders. There is no OS push notification system.

### 4. Creating a plan

You can create a personal plan for the current (or next) month, copy an earlier plan’s structure, or create a **household** plan with a name and optional invites. Periods are monthly, biweekly (14 days), or a custom range. Saving may warn about overlaps, empty plans, or planned spend above income — those are confirmations, not hard blocks (except invalid income above the hard max).

### 5. Logging life

Add income or expense events against a selected budget (amount, date, category/subcategory, optional note). Expenses never change planned category amounts; income events never change planned income.

### 6. Sharing

A household has members and one or more period documents. Invite by email (invitee must already have an account). Accept adds the person to the household and every period under that household; decline closes the invite. Everyone on the plan logs events on the same shared periods.

### 7. Chatbot

The chatbot is an onboarding helper that asks about housing, transport, food, and similar topics, then saves a **personal** budget. It does not create household plans. Some answers are yearly costs stored as monthly equivalents; biweekly plans store half of a monthly-style answer.

---

## Where the code lives (short)

| You want to change… | Start here |
| --- | --- |
| Login / session / first screen after login | `lib/features/auth/` |
| Plan math, events, create/edit, summary tracking | `lib/features/budget/` (rules in `domain/`) |
| Chatbot questions and save | `lib/features/chatbot/` |
| Tabs, app bar, menus, reminder triggers | `lib/features/mainscreen/` |
| Banner UI | `lib/features/notification/` |
| Event history list | `lib/features/history/` |
| APK updater | `lib/features/update/` |
| Theme, router, default categories | `lib/core/` |

State is wired with the `provider` package in `lib/main.dart`. Firestore access for budgets and events goes through repositories.

---

## Data in plain language

- **Your personal plans** sit under your user id.
- **Household** is a group (name + members). Each shared period is a separate document that points at that household and keeps a copy of member ids for queries.
- **Events** hang off personal or shared storage and always point at a budget id.
- **Invites** are their own documents, keyed by invitee email (normalized).

Exact paths: [`architecture.md`](architecture.md#persistence-map).

---

## How to verify behavior

Unit tests cover domain rules without booting Firebase. See [`tests.md`](tests.md) for commands and coverage. If something in production surprises you, the tests and [`domain.md`](domain.md) caveats should describe current behavior — change the spec and tests together when you intentionally change it.

---

## Related docs

- [`architecture.md`](architecture.md) — modules, layers, persistence map
- [`domain.md`](domain.md) — budgets, events, tracking, shared, reminders
- [`designthoughts.md`](designthoughts.md) — product opinions (not the spec)
- Feature `*_rework.md` files — deeper “how this feature is wired today” notes
