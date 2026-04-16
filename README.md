# plot_manager

Plot Manager is a Flutter app for managing rental plots, units, tenants, and finances.

## Features

- Organization and property setup
- Unit management with occupancy rules
- Tenant move-in workflow
- Secure unit deletion verification

### Phase 4: Financials

- M-Pesa parsing from pasted SMS (auto-fills payment amount and reference)
- Automated rent calculation in Unit Detail (Total Paid this Month vs Balance Due)
- Responsive finance dashboard and payment history views

## Getting Started

1. Install Flutter SDK.
2. Run `flutter pub get`.
3. Configure the PostgreSQL backend in `backend/.env`:
   - `PORT=4000`
   - `JWT_SECRET=<long-random-secret>`
   - `DATABASE_URL=postgresql://postgres:postgres@localhost:5432/plot_manager`
4. Create the local database and run schema bootstrap:

```bash
createdb plot_manager
psql -d plot_manager -f sql/schema/postgres_bootstrap.sql
```

1. Start the backend from `backend/` with `npm run dev`.
2. Start the Flutter app from the repository root with `flutter run`.

The app now chooses a local backend URL automatically: `127.0.0.1:4000` on desktop and `10.0.2.2:4000` on Android emulator. If you move the backend to another host, set `API_BASE_URL` in the Flutter launch config or pass it as a dart define.

The old Supabase setup files are no longer part of the primary run path. The app now expects the backend API to talk to your local PostgreSQL database.

## Always-On Cloud Setup (Beginner Friendly)

If you do not want to keep your laptop backend running, deploy the API and database to Railway.

1. Go to Railway dashboard and create a new project.
2. Add a PostgreSQL service inside the same Railway project.
3. Add a GitHub service and connect this repository.
4. In Railway service settings, set the root directory to `backend`.
5. In Railway variables, set:
   - `PORT=4000`
   - `JWT_SECRET=<a long random secret>`
   - `DATABASE_URL=<Railway Postgres connection string>`
6. Open the PostgreSQL service, copy the connection string, and paste it into `DATABASE_URL`.
7. In Railway deploy settings, ensure health check path is `/health`.
8. Deploy and wait until status is healthy.
9. Copy your backend public URL from Railway, for example `https://your-api.up.railway.app`.

After backend is live, run Flutter using the cloud API URL:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.up.railway.app
```

If you are building a release APK/IPA, pass the same `API_BASE_URL` at build time.

## Running Automated Tests (CLI)

V1.5: Iron-Clad Logic (11+ Automated Tests Passing).

Run all tests:

```bash
flutter test
```

Run Phase 10 test suites only:

```bash
flutter test test/finance_logic_test.dart
flutter test test/maintenance_widget_test.dart
```
