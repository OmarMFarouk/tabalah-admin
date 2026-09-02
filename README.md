# Tabalah Admin

The back-office desktop panel for [أكاديمية تبالة الرياضية](https://tabalahacademy.com).

A Flutter **Windows** application used by academy staff to run the club: people,
catalogue, sessions, money, reporting and access control. Arabic-first (RTL).

Backend: [tabalah-backend](https://github.com/OmarMFarouk/tabalah-backend) ·
Member app: [tabalah-app](https://github.com/OmarMFarouk/tabalah-app)

---

## Getting started

```bash
flutter pub get
flutter run -d windows
```

Requires the Flutter desktop toolchain: Visual Studio with the
**Desktop development with C++** workload.

### Release build

```bash
flutter build windows --release
```

Output is `build/windows/x64/runner/Release/`. It is self-contained — ship the whole
folder (`TabalahAdmin.exe`, the plugin DLLs and `data/`), not the `.exe` alone.

---

## Screens

| Screen | Covers |
|---|---|
| `dashboard` | today's activity, headline figures |
| `people` | players, trainers, employees |
| `catalog` | sports, memberships, schedules |
| `sessions` | session board, generation, rescheduling |
| `finance` | payments, payment sources, salaries, enrolments |
| `performance` | KPIs and KPI records |
| `reports` | exportable summaries |
| `comms` | custom email and newsletters |
| `user_audit` | audit trail per user |
| `guardian_share` | issue and rotate a player's parent-portal code |
| `settings` | roles, permissions, account |

---

## Architecture

```
lib/
├── blocs/        one cubit per domain (people, catalog, finance, reports, …)
├── models/       API response models
├── components/   shared desktop widgets — tables, dialogs, modal pages
├── screens/      one file per screen above
├── services/     HTTP client and per-domain API wrappers
└── src/          theme, endpoints, permissions, destinations, globals
```

State management is **flutter_bloc** (cubits). Networking is the **http** package.
Tokens live in `flutter_secure_storage`; window sizing uses **window_manager**.

`lib/src/app_endpoints.dart` is the single source of the API base URL.

### Permissions

`lib/src/app_permissions.dart` mirrors the backend's permission set. The UI hides what
the signed-in user may not do, but this is **presentation only** — the server enforces
access independently through its `role` and `permission` middleware. Never treat a
hidden button as a security boundary.

### Money

All amounts are Saudi Riyals. `FinanceModel.symbolFor()` maps ISO codes to symbols and
falls back to the raw code, so a row in another currency renders honestly rather than
being silently relabelled as riyals.

---

## Notes

- **`lib_old/`** is superseded source kept from before this repo existed. It is not
  referenced by the running app and can be deleted once nothing is being ported out of
  it.
- **Staff-created accounts are auto-verified.** The backend requires email verification
  before sign-in, and accounts created here skip it — staff creating the account is the
  vouching. Members who sign up through the app must verify by email.
