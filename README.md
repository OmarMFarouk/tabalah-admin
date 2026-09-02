# Tabalah Club — لوحة تحكم النادي

Flutter Windows desktop admin panel for the Tabalah Club API. Built to match
the reference cashier app's visual language, folder layout, and coding
conventions, and wired to every endpoint in the Postman collection's **Admin**
folder.

---

## Running it

The archive contains `lib/`, `assets/`, and `pubspec.yaml` — the portable part
of a Flutter project. The platform shells (`windows/`, `build/`, etc.) are
generated, so create them fresh:

```bash
flutter create --platforms=windows tabalah_admin
cd tabalah_admin

# copy lib/, assets/ and pubspec.yaml from this archive over the generated ones

flutter pub get
flutter run -d windows
```

Run `flutter analyze` on first open. The project was written without a Flutter
toolchain available in the build environment, so it has been verified
structurally (delimiter balance, import resolution, cross-file symbol
reachability) but never compiled.

**Minimum window size is 1100×700**, set in `lib/src/app_presets.dart`. The
tables assume that width.

---

## Pointing it at your server

Base URL lives in one place:

```dart
// lib/src/app_endpoints.dart
static const String baseUrl = 'http://localhost:8000/api/v1';
```

Everything else derives from it. Log in with a staff account — the panel
rejects `player` tokens at the login gate, before any screen loads.

---

## Sixteen API folders, seven pages

The brief asked for as few pages as possible, with related things sharing a
page. The mapping:

| Page | Absorbs |
|---|---|
| **الرئيسية** Dashboard | Dashboard |
| **الأشخاص** People | Users · Players · Trainers · Employees |
| **الاشتراكات** Catalog | Sports · Memberships · Schedules |
| **الحصص** Sessions | Sessions (+ board) · Attendance · Ratings |
| **المالية** Finance | Payments · **Payment Sources** · Enrollments |
| **الأداء** Performance | KPIs · KPI Records · Salaries |
| **المراسلات** Comms | Emails · Newsletters |

Payment sources sit on the Finance page, as requested. Enrollments joined them
because recording a payment against an enrollment activates that enrollment in
the same transaction — one front-desk workflow, so one page. The payment
dialog has a shortcut into the sources tab so the desk never has to leave it.

---

## Layout

```
lib/
├── main.dart
├── src/                    presets, colours, endpoints, storage, globals
├── models/                 response parsing
├── services/apis/          one thin class per resource over a shared ApiClient
├── blocs/                  one cubit per page + a single shared state file
├── components/
│   ├── general/            the shared widget layer (see below)
│   └── index/appbar.dart   frameless window chrome + navigation
└── screens/                seven pages + login + shell
```

### What was deliberately not carried over

The reference app's structure was followed, but its duplication was not:

- **No `components/trash/`** — dead code folder.
- **No parallel `screens/` and `view/main/` trees** — the reference keeps two
  copies of every screen. This has one.
- **No `client_details copy.dart`, `old_cashier_sheet.dart`, or `app_bar.dart`
  beside `appbar.dart`.**
- **The big one:** the reference pastes `_dashCard`, `_headerBtn`, `_colHeader`,
  `_field`, `_toggleTab`, and `_buildEmpty` into every screen. Those are now
  six files in `components/general/` — `stat_card`, `page_header`, `app_table`,
  `app_field`, `app_dialog`, `empty_widget`. Every page draws from them, which
  is why seven feature pages fit in ~12k lines.
- **One `base_states.dart`** instead of eight near-identical state files.
- **Ten dependencies instead of twenty** — the printing, Excel, camera, and
  charting packages aren't used here and aren't pulled in.

---

## Behaviour worth knowing

These come from the API's own documentation and are enforced in the UI:

- **Roles.** Employees get read access plus write on enrollments and
  attendance. Admins get everything except staff accounts and role escalation.
  Owners get the rest. Buttons disable rather than fail — the delete on a
  trainer with active memberships is greyed with a tooltip explaining why,
  instead of surfacing a 422.
- **Payments are immutable.** Amount and payer can't be edited; the correction
  path is refund and re-record. The edit dialog says so and only exposes the
  source and notes.
- **Refunding cancels the linked enrollment.** The confirm dialog states it.
- **Retiring a payment source** means deactivating it. Delete is only offered
  when `payments_count` is zero.
- **`is_default` is a singleton** — promoting one source demotes the previous.
- **Payment totals** (collected/pending/refunded) are computed server-side over
  the whole filtered set, not the current page, so the stat cards always agree
  with the filters above them.
- **Session generation is idempotent** — safe to re-run over a wider date range.
- **Ratings are moderated, not deleted** — the action adds a supervisor note.

---

## Language

The UI is Arabic RTL to match the reference app; the API is English. If you
want English LTR, the changes are contained: swap the `Directionality`
wrappers in `screens/` and `components/index/appbar.dart` to
`TextDirection.ltr`, and replace the Arabic label strings — they're
concentrated in the `*Ar` getters on the models and the tab-label extensions
in `blocs/`.
