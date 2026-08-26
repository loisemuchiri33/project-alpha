# ZENI — Smart Loans. Secure Future.

Production-oriented digital lending platform for Kenya (Tala-class architecture).
Designed for high concurrency, CBK-aligned security controls, and M-Pesa payment rails.

> Hosting is intentionally deferred. Run locally with Docker Compose for PostgreSQL, Redis, and MinIO.
> **Never** deploy with compose/dev default passwords on a public host.

## Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter (Android / iOS) |
| Admin | Flutter Web |
| API | Go 1.22 + Gin |
| DB | PostgreSQL 16 |
| Cache | Redis 7 |
| Objects | MinIO |
| Payments | Safaricom M-Pesa Daraja (STK / callbacks) |
| Infra | Docker Compose, Nginx, Kubernetes manifests, Prometheus, GitHub Actions |

## Quick start

```bash
# 1. Infrastructure (ports bound to 127.0.0.1 only)
docker compose up -d

# 2. Backend
cd backend
cp .env.example .env
# REQUIRED before any real traffic:
#   openssl rand -hex 32   → JWT_SECRET, MPESA_CALLBACK_SECRET
#   32-byte ASCII key      → ENCRYPTION_KEY (when wired)
# Set GIN_MODE=release for production (fails closed on weak JWT).
go mod tidy
go run ./cmd/api/

# Optional worker
go run ./cmd/worker/

# 3. Mobile
cd mobile/zeni_app
flutter pub get
flutter run

# 4. Admin web
cd admin/zeni_admin
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080/api/v1
```

Health: `GET http://localhost:8080/health`

## Bootstrap first CEO (superadmin)

```bash
export CEO_PHONE=2547XXXXXXXX
export CEO_PASSWORD="$(openssl rand -base64 24)"
export CEO_EMAIL=ceo@yourdomain.example   # optional
./scripts/create_ceo.sh
# Login to admin with those values — script does not print the password.
```

## Repository layout

```
zeni/
  backend/           # Go API + worker
  admin/zeni_admin/  # Flutter web ops desk
  mobile/zeni_app/   # Flutter borrower app
  infrastructure/    # k8s, nginx, prometheus
  scripts/           # ops helpers (no hardcoded secrets)
  docs/              # security notes + architecture
  docker-compose.yml # local deps only (loopback binds)
```

## Product notes

Loan ladder (KES):

5,000 → 10,000 → 15,000 → 20,000 → 25,000 → 30,000 → 35,000

Phone numbers normalize to `254XXXXXXXXX`.

## Security highlights

- Argon2id passwords, AES-256-GCM field encryption helper
- JWT access/refresh; release mode rejects weak/missing `JWT_SECRET`
- Admin routes behind `Auth` + `AdminRequired` RBAC
- Payment intents bind STK to loans; M-Pesa callback requires header secret in release
- Rate limits + security headers + CORS allowlist
- Staff/activity audit tables (migration `003_staff_and_activity`)
- See `docs/SECURITY.md`, `docs/SECURITY_FIXES.md`, `docs/SECURITY_ASSESSMENT_2026-08-13.md`

## Local infrastructure defaults (dev only)

Compose falls back to **dev-only** passwords if env vars are unset. Override via environment
or a gitignored `.env` next to `docker-compose.yml`:

| Service | Env vars | Notes |
|---------|----------|--------|
| Postgres | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Bound `127.0.0.1:5432` |
| Redis | `REDIS_PASSWORD` | Bound `127.0.0.1:6379` |
| MinIO | `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` | Bound `127.0.0.1:9000/9001` |

**Do not use compose defaults outside a private laptop.** K8s `infrastructure/k8s/secrets.yaml` is a placeholder template only.

## Makefile

```bash
make up          # docker compose up -d
make down
make api         # run API
make worker
make test        # go test ./...
```
