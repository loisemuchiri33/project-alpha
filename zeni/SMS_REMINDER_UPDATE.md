# ZENI – Updated with Payment SMS Reminders

## What is new

Workers (admin / superadmin) can send SMS payment reminders to borrowers.

### New endpoint
```
POST /api/v1/admin/loans/:id/remind
Authorization: Bearer <staff_token>
Content-Type: application/json

{ "message": "optional custom text" }   // optional
```

### Default SMS text
```
Dear [Name], your ZENI loan balance of KES XXX is due on DD Mon YYYY.
Please repay via M-Pesa to avoid late fees. - ZENI
```

### Environment variables (add to backend/.env)
```
SMS_PROVIDER=africastalking
SMS_USERNAME=your_africastalking_username
SMS_API_KEY=your_api_key
SMS_SENDER_ID=ZENI
SMS_BASE_URL=https://api.africastalking.com
```

If `SMS_API_KEY` is empty, the API only logs the message (safe for local testing).

### How to test
1. `docker compose up -d`
2. Configure `backend/.env` (set JWT_SECRET and SMS_* if you have keys)
3. `cd backend && go run ./cmd/api/`
4. Create CEO: `./scripts/create_ceo.sh` (see main README)
5. Login to admin as CEO → create a worker → approve a loan → call the remind endpoint
   or use the admin UI once a “Send Reminder” button is added.

Every reminder is written to the audit log (`send_payment_reminder`) so the superadmin can see who sent it and when.
