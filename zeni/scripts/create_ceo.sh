#!/usr/bin/env bash
# Bootstrap the first superadmin (CEO) account.
# Requires env vars — never commit real credentials.
#
# Usage (from monorepo root, API up, docker compose up):
#   export CEO_PHONE=2547XXXXXXXX
#   export CEO_PASSWORD='long-random-password'
#   export CEO_EMAIL=ceo@example.com   # REQUIRED for staff email OTP login
#   export CEO_FIRST=Zeni CEO_LAST=CEO # optional
#   ./scripts/create_ceo.sh

set -euo pipefail

API="${API:-http://127.0.0.1:8080}"
CEO_PHONE="${CEO_PHONE:-}"
CEO_PASSWORD="${CEO_PASSWORD:-}"
CEO_EMAIL="${CEO_EMAIL:-}"
CEO_FIRST="${CEO_FIRST:-Zeni}"
CEO_LAST="${CEO_LAST:-CEO}"

if [[ -z "$CEO_PHONE" || -z "$CEO_PASSWORD" || -z "$CEO_EMAIL" ]]; then
  echo "ERROR: set CEO_PHONE, CEO_PASSWORD and CEO_EMAIL." >&2
  echo "Example:" >&2
  echo "  CEO_PHONE=2547XXXXXXXX CEO_PASSWORD=\$(openssl rand -base64 24) $0" >&2
  exit 1
fi

if [[ ${#CEO_PASSWORD} -lt 12 ]]; then
  echo "ERROR: CEO_PASSWORD must be at least 12 characters." >&2
  exit 1
fi

BODY=$(python3 - <<'PY' "$CEO_PHONE" "$CEO_PASSWORD" "$CEO_FIRST" "$CEO_LAST" "$CEO_EMAIL"
import json, sys
phone, password, first, last, email = sys.argv[1:6]
payload = {
    "phone": phone,
    "password": password,
    "first_name": first,
    "last_name": last,
}
if email:
    payload["email"] = email
print(json.dumps(payload))
PY
)

echo "1) Registering CEO (or reusing existing phone)..."
curl -sS -X POST "$API/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "$BODY" || true

echo ""
echo "2) Promoting to superadmin..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-zeni}" -d "${POSTGRES_DB:-zeni}" -c \
  "UPDATE users SET role = 'superadmin', email = lower('${CEO_EMAIL//\'/\'\'}'), first_name = '${CEO_FIRST//\'/\'\'}', last_name = '${CEO_LAST//\'/\'\'}', is_active = true WHERE phone = '${CEO_PHONE//\'/\'\'}';"

echo ""
echo "3) Verify:"
docker compose exec -T postgres psql -U "${POSTGRES_USER:-zeni}" -d "${POSTGRES_DB:-zeni}" -c \
  "SELECT phone, first_name, last_name, role, is_active FROM users WHERE role = 'superadmin';"

echo ""
echo "Done. Login to admin with the phone/email and password you supplied (not printed)."
