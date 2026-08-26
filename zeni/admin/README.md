# ZENI Ops Admin (Flutter Web)

Staff console for portfolio monitoring and loan underwriting.

## Run

```bash
cd admin/zeni_admin
flutter pub get
flutter run -d chrome
```

Default API: `http://localhost:8080/api/v1`
Override: `--dart-define=API_BASE=https://api.zeni.co.ke/api/v1`

## Features

| Screen | What workers do |
|--------|-----------------|
| **Portfolio** | Active loans, disbursed/collected, default rate, pending KYC/queue counts |
| **Queue** | Pending applications · **Approve** / **Reject** (with reason) |
| **Health** | Admin API health |
| **Demo mode** | Offline UI without API/Postgres |

## Staff accounts

```sql
UPDATE users SET role = 'admin' WHERE phone = '2547XXXXXXXX';
-- roles: user | agent | admin | superadmin
-- only admin/superadmin can approve/reject
```

JWT includes `role` from DB. All `/admin/*` routes require Bearer token + admin role.
