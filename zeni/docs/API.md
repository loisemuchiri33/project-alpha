# ZENI API Reference

Base URL: `http://localhost:8080/api/v1`

## Auth
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | No | Register with phone + password |
| POST | `/auth/login` | No | Login |
| POST | `/auth/otp/send` | No | Send OTP |
| POST | `/auth/otp/verify` | No | Verify OTP |
| POST | `/auth/refresh` | No | Refresh tokens |
| POST | `/auth/change-password` | Yes | Change password |

## Loans
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/loans` | Yes | Apply for loan (fixed **30-day** tenor only) |
| GET | `/loans` | Yes | List user loans |
| GET | `/loans/:id` | Yes | Loan detail |
| POST | `/admin/loans/:id/approve` | Admin | Approve loan |

## Payments
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/payments/stk` | Yes | Trigger M-Pesa STK |
| POST | `/payments/callback` | Public | Daraja callback |

## KYC / User / Admin
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/kyc` | Yes | Submit KYC |
| GET | `/kyc/status` | Yes | KYC status |
| GET | `/user/profile` | Yes | Profile |
| GET | `/admin/dashboard` | Admin | Metrics |
| GET | `/health` | No | Health check |

### Phone format
Normalize to `254XXXXXXXXX` (Kenya).
