# Supabase Cloud Backup — LEE Sale Monitor

The app's cloud backup lives in the shared Supabase project
`ozqktruzxyjcozalsbqj` (also used by Lee_shop). All tables are prefixed
`lee_sale_` so the two apps never collide.

## Tables

`lee_sale_category_rates`, `lee_sale_sales`, `lee_sale_payments`,
`lee_sale_investors`, `lee_sale_expenses`, `lee_sale_profit_shares`,
`lee_sale_backups`.

## Auth

Firebase Auth is a third-party provider in Supabase. The Supabase client is
initialised with an `accessToken` callback that returns the Firebase ID token.
RLS policies compare `auth.jwt()->>'sub'` (the Firebase UID) against the
`owner_uid` text column.

### Required one-time setup (Firebase custom claim)

Every Firebase user must carry `{ "role": "authenticated" }` or Supabase maps
the request to `anon` and RLS returns no rows.

1. Firebase Console → Project Settings → Service accounts → Generate new private key.
2. Save as `tools/firebase_claim/service-account.json` (git-ignored).
3. `cd tools/firebase_claim && npm install && npm run set-claims`.
4. Re-run whenever you add a new staff account.

### Supabase dashboard setup

Authentication → Third-Party Auth → Add Firebase → Project ID `lee-sale-monitor-app`.

## Backup / restore flow

- **Back up to cloud** — upserts all six tables (500 rows/batch) with
  last-write-wins by `updated_at`, then writes a `lee_sale_backups` log row.
- **Restore from cloud** — paginated download (1,000/page) merged into SQLite
  with the same newer-wins rule.
- Auto-restore runs once on login.
- Export/restore of the `.db` file remains as a safety net.

## Build

```powershell
flutter run --dart-define-from-file=env/dev.json
flutter build appbundle --release --dart-define-from-file=env/prod.json
```

## Verifying RLS

The SQL editor has no request JWT, so test from the app (or with a Firebase ID
token via curl). Confirm user A sees only their rows and user B sees none of A's.
