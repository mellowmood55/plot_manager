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
3. Configure Supabase credentials in `lib/core/supabase_config.dart`.
4. Run SQL migrations from the repository root:
   - `unit_configurations_setup.sql`
   - `unit_number_canonicalization.sql`
   - `payments_phase4.sql`
5. Start the app with `flutter run`.

## Running Automated Tests (CLI)

Run all tests:

```bash
flutter test
```

Run Phase 10 test suites only:

```bash
flutter test test/finance_logic_test.dart
flutter test test/maintenance_widget_test.dart
```
