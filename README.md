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
3. Configure the Neon backend in `backend/.env`:
   - `PORT=4000`
   - `JWT_SECRET=<long-random-secret>`
   - `NEON_DATABASE_URL=<your-neon-postgres-url>`
4. Start the backend from `backend/` with `npm run dev`.
5. Start the Flutter app from the repository root with `flutter run`.

The app now chooses a local backend URL automatically: `127.0.0.1:4000` on desktop and `10.0.2.2:4000` on Android emulator. If you move the backend to another host, set `NEON_API_BASE_URL` in the Flutter launch config or pass it as a dart define.

The old Supabase setup files are no longer part of the primary run path. The app now expects the backend API to talk to the current Neon database.

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
