# CEO worker login / logout visibility

## What the CEO sees
- **Activity → Sessions**: per-worker online/offline status, last login time + IP, last logout time + IP
- **Activity → Full audit trail**: every `login`, `logout`, `login_failed`, loan approve/reject/disburse, worker create/deactivate
- Filters: All | Logins | Logouts | Failed logins

## How it works
1. Staff signs in via `POST /api/v1/auth/login` → audit `login` + `users.last_login_at`
2. Staff signs out via rail **Sign out** → `POST /api/v1/admin/logout` → audit `logout` + access token JTI denylisted
3. CEO loads `GET /api/v1/admin/activity` and `GET /api/v1/admin/sessions` (superadmin only)

## Demo mode
Offline demo seeds sample login/logout rows so the CEO desk is reviewable without a live API.
