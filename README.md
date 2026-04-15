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

Project location for this setup:

- `C:/xampp/htdocs/plot_manager`

1. Install Flutter SDK.
2. Run `flutter pub get`.
3. Create a Supabase project and open the SQL editor.
4. Run `sql/schema/postgres_bootstrap.sql` in Supabase to create a fresh empty schema.
5. Configure the backend in `backend/.env`:
   - `PORT=4000`
   - `JWT_SECRET=<long-random-secret>`
   - `DATABASE_URL=postgresql://postgres:<your-password>@db.<project-ref>.supabase.co:5432/postgres`

6. Start the backend from `backend/` with `npm run dev` or deploy it to Railway.
7. Start the Flutter app from the repository root with `flutter run`.

The app now chooses a local backend URL automatically: `127.0.0.1:4000` on desktop and `10.0.2.2:4000` on Android emulator. If you run on a physical Android device or move the backend to another host, set `API_BASE_URL` in the Flutter launch config or pass it as a dart define.

The backend now uses Supabase PostgreSQL and expects a fresh empty schema created from `sql/schema/postgres_bootstrap.sql`.

## Always-On Cloud Setup (Beginner Friendly)

If you do not want to keep your laptop backend running, deploy the API to Railway and keep the database in Supabase.

1. Go to Railway dashboard and create a new project.
2. Add a GitHub service and connect this repository.
3. In Railway service settings, set the root directory to `backend`.
4. In Railway variables, set:
   - `PORT=4000`
   - `JWT_SECRET=<a long random secret>`
   - `DATABASE_URL=<Supabase connection string>`
5. In Railway deploy settings, ensure health check path is `/health`.
6. Deploy and wait until status is healthy.
7. Copy your backend public URL from Railway, for example `https://your-api.up.railway.app`.

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
