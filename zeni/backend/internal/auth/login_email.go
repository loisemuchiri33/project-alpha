package auth

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/google/uuid"
)

// LoginRequest accepts phone OR email for staff/borrower login.
type LoginRequestFlexible struct {
	Phone    string `json:"phone"`
	Email    string `json:"email"`
	Password string `json:"password" binding:"required"`
}

// StaffLoginChallenge is returned when password is correct but email OTP is still required.
type StaffLoginChallenge struct {
	RequiresEmailOTP bool      `json:"requires_email_otp"`
	UserID           uuid.UUID `json:"user_id"`
	EmailHint        string    `json:"email_hint"`
	ExpiresIn        int       `json:"expires_in"`
	Message          string    `json:"message"`
}

// LoginResult is either a full AuthResponse (borrowers / after OTP) or a staff challenge.
type LoginResult struct {
	Auth      *AuthResponse
	Challenge *StaffLoginChallenge
}

// LoginWithEmailOrPhone authenticates by email if provided, otherwise by phone.
// Staff accounts always require a second step: email OTP (5 minutes).
func (s *Service) LoginWithEmailOrPhone(ctx context.Context, phone, email, password string) (*LoginResult, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	phone = strings.TrimSpace(phone)

	var user *User
	var err error

	if email != "" {
		if finder, ok := s.repo.(interface {
			FindByEmail(ctx context.Context, email string) (*User, error)
		}); ok {
			user, err = finder.FindByEmail(ctx, email)
		} else {
			return nil, ErrInvalidCredentials
		}
	} else if phone != "" {
		user, err = s.repo.FindByPhone(ctx, normalizePhone(phone))
	} else {
		return nil, ErrInvalidCredentials
	}

	if err != nil || user == nil || !user.IsActive {
		return nil, ErrInvalidCredentials
	}
	if !verifyPassword(user.PasswordHash, password) {
		return nil, ErrInvalidCredentials
	}

	if IsStaffRole(user.Role) {
		if strings.TrimSpace(user.Email) == "" {
			return nil, ErrEmailRequired
		}
		challenge, err := s.beginStaffEmailOTP(ctx, user)
		if err != nil {
			return nil, err
		}
		return &LoginResult{Challenge: challenge}, nil
	}

	authResp, err := s.issueTokens(user)
	if err != nil {
		return nil, err
	}
	s.logger.Info("user logged in", "user_id", user.ID, "role", user.Role)
	return &LoginResult{Auth: authResp}, nil
}

func (s *Service) beginStaffEmailOTP(ctx context.Context, user *User) (*StaffLoginChallenge, error) {
	code, err := generateNumericOTP(6)
	if err != nil {
		return nil, fmt.Errorf("generate otp: %w", err)
	}
	otp := &OTP{
		Code:      code,
		ExpiresAt: time.Now().Add(5 * time.Minute),
		Attempts:  0,
	}
	key := staffOTPKey(user.ID)
	if err := s.otpStore.Set(ctx, key, otp); err != nil {
		return nil, fmt.Errorf("store otp: %w", err)
	}

	subject := "ZENI Admin - your login code"
	body := fmt.Sprintf(
		"Hi %s,\n\nYour ZENI staff login code is: %s\n\nIt expires in 5 minutes. If you did not try to sign in, ignore this email.\n\n- ZENI Ops\n",
		strings.TrimSpace(user.FirstName+" "+user.LastName),
		code,
	)

	if s.emailSender != nil {
		if err := s.emailSender.Send(user.Email, subject, body); err != nil {
			s.logger.Error("staff login email failed", "user_id", user.ID, "error", err)
		}
	} else {
		s.logger.Info("staff login OTP (no email sender)", "user_id", user.ID, "code", code)
	}

	if s.cfg != nil && (s.cfg.Email.Host == "" || s.cfg.Email.User == "") {
		s.logger.Info("STAFF LOGIN CODE (dev)", "email", user.Email, "code", code)
	}

	return &StaffLoginChallenge{
		RequiresEmailOTP: true,
		UserID:           user.ID,
		EmailHint:        maskEmailHint(user.Email),
		ExpiresIn:        300,
		Message:          "A verification code was sent to your email. Enter it to continue.",
	}, nil
}

// VerifyStaffEmailOTP checks the 6-digit code and issues tokens on success.
func (s *Service) VerifyStaffEmailOTP(ctx context.Context, userID uuid.UUID, code string) (*AuthResponse, error) {
	code = strings.TrimSpace(code)
	if len(code) < 4 {
		return nil, ErrInvalidOTP
	}
	user, err := s.repo.FindByID(ctx, userID)
	if err != nil || user == nil || !user.IsActive {
		return nil, ErrInvalidCredentials
	}
	if !IsStaffRole(user.Role) {
		return nil, ErrInvalidCredentials
	}

	key := staffOTPKey(userID)
	otp, err := s.otpStore.Get(ctx, key)
	if err != nil || otp == nil {
		return nil, ErrInvalidOTP
	}
	if time.Now().After(otp.ExpiresAt) || otp.Attempts >= 5 {
		_ = s.otpStore.Delete(ctx, key)
		return nil, ErrInvalidOTP
	}
	if otp.Code != code {
		otp.Attempts++
		_ = s.otpStore.Set(ctx, key, otp)
		return nil, ErrInvalidOTP
	}
	_ = s.otpStore.Delete(ctx, key)

	authResp, err := s.issueTokens(user)
	if err != nil {
		return nil, err
	}
	s.logger.Info("staff logged in via email OTP", "user_id", user.ID, "role", user.Role)
	return authResp, nil
}

func (s *Service) issueTokens(user *User) (*AuthResponse, error) {
	accessToken, err := s.tokenGen.GenerateAccessToken(user)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}
	refreshToken, err := s.tokenGen.GenerateRefreshToken(user)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}
	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    s.cfg.JWT.AccessTTL,
		User:         user,
	}, nil
}

func staffOTPKey(userID uuid.UUID) string {
	return fmt.Sprintf("staff_login_otp:%s", userID.String())
}

func generateNumericOTP(digits int) (string, error) {
	var b strings.Builder
	for i := 0; i < digits; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}
		b.WriteByte(byte('0' + n.Int64()))
	}
	return b.String(), nil
}

func maskEmailHint(email string) string {
	email = strings.TrimSpace(strings.ToLower(email))
	parts := strings.SplitN(email, "@", 2)
	if len(parts) != 2 {
		return "***"
	}
	local := parts[0]
	if len(local) <= 2 {
		return "***@" + parts[1]
	}
	return local[:2] + "***@" + parts[1]
}
