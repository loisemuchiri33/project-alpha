package auth

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/argon2"
	"golang.org/x/text/cases"
	"golang.org/x/text/language"

	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/pkg/logger"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUserNotFound       = errors.New("user not found")
	ErrUserExists         = errors.New("user already exists")
	ErrInvalidOTP         = errors.New("invalid or expired OTP")
	ErrEmailRequired      = errors.New("staff account requires a verified email")
	ErrStaffOTPRequired   = errors.New("email verification code required")
	ErrTokenExpired       = errors.New("token expired")
	ErrTokenInvalid       = errors.New("token invalid")
)

type Service struct {
	cfg         *config.Config
	logger      *logger.Logger
	repo        UserRepository
	otpStore    OTPStore
	tokenGen    TokenGenerator
	emailSender EmailSender
}

// EmailSender sends transactional email (staff login OTP).
type EmailSender interface {
	Send(to, subject, body string) error
}

type UserRepository interface {
	Create(ctx context.Context, user *User) error
	FindByPhone(ctx context.Context, phone string) (*User, error)
	FindByID(ctx context.Context, id uuid.UUID) (*User, error)
	Update(ctx context.Context, user *User) error
	UpdatePassword(ctx context.Context, userID uuid.UUID, hash string) error
}

type OTPStore interface {
	Set(ctx context.Context, key string, otp *OTP) error
	Get(ctx context.Context, key string) (*OTP, error)
	Delete(ctx context.Context, key string) error
}

type TokenGenerator interface {
	GenerateAccessToken(user *User) (string, error)
	GenerateRefreshToken(user *User) (string, error)
	VerifyToken(tokenStr string) (*Claims, error)
	VerifyTokenOfType(tokenStr string, wantType string) (*Claims, error)
}

type User struct {
	ID              uuid.UUID `json:"id" db:"id"`
	Phone           string    `json:"phone" db:"phone"`
	Email           string    `json:"email" db:"email"`
	FirstName       string    `json:"first_name" db:"first_name"`
	LastName        string    `json:"last_name" db:"last_name"`
	PasswordHash    string    `json:"-" db:"password_hash"`
	Role            string    `json:"role" db:"role"`
	KYCStatus       string    `json:"kyc_status" db:"kyc_status"`
	CreditScore     int       `json:"credit_score" db:"credit_score"`
	RiskLevel       string    `json:"risk_level" db:"risk_level"`
	LoanLimit       float64   `json:"loan_limit" db:"loan_limit"`
	IsActive        bool      `json:"is_active" db:"is_active"`
	IsPhoneVerified bool      `json:"is_phone_verified" db:"is_phone_verified"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}

// Staff roles that may access /admin routes.
func IsStaffRole(role string) bool {
	switch role {
	case "admin", "superadmin", "agent":
		return true
	default:
		return false
	}
}

// Roles allowed to approve/reject loans.
func CanApproveLoans(role string) bool {
	return role == "admin" || role == "superadmin"
}

type OTP struct {
	Code      string    `json:"code"`
	ExpiresAt time.Time `json:"expires_at"`
	Attempts  int       `json:"attempts"`
}

type RegisterRequest struct {
	Phone     string `json:"phone" validate:"required,regexp=^254[0-9]{9}$"`
	FirstName string `json:"first_name" validate:"required,min=2,max=50"`
	LastName  string `json:"last_name" validate:"required,min=2,max=50"`
	Email     string `json:"email" validate:"omitempty,email"`
	Password  string `json:"password" validate:"required,min=8,max=128"`
}

type LoginRequest struct {
	Phone    string `json:"phone"`
	Email    string `json:"email"`
	Password string `json:"password" validate:"required"`
}

type AuthResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
	User         *User  `json:"user"`
}

type Claims struct {
	UserID    uuid.UUID `json:"user_id"`
	Phone     string    `json:"phone"`
	Role      string    `json:"role"`
	TokenType string    `json:"typ,omitempty"`
	jwt.RegisteredClaims
}

func NewService(cfg *config.Config, logger *logger.Logger, repo UserRepository, otpStore OTPStore, tokenGen TokenGenerator) *Service {
	return &Service{cfg: cfg, logger: logger, repo: repo, otpStore: otpStore, tokenGen: tokenGen}
}

func (s *Service) SetEmailSender(e EmailSender) { s.emailSender = e }

func (s *Service) Register(ctx context.Context, req *RegisterRequest) (*User, error) {
	phone := normalizePhone(req.Phone)
	existing, _ := s.repo.FindByPhone(ctx, phone)
	if existing != nil {
		return nil, ErrUserExists
	}
	hash, err := hashPassword(req.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}
	user := &User{
		ID: uuid.New(), Phone: phone, Email: req.Email,
		FirstName: toTitle(req.FirstName), LastName: toTitle(req.LastName),
		PasswordHash: hash, Role: "user", KYCStatus: "not_submitted", CreditScore: 500,
		RiskLevel: "medium", LoanLimit: 0, IsActive: true,
		IsPhoneVerified: false, CreatedAt: time.Now(), UpdatedAt: time.Now(),
	}
	if err := s.repo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}
	s.SendOTP(ctx, phone)
	s.logger.Info("user registered", "user_id", user.ID, "phone", phone)
	return user, nil
}

func (s *Service) Login(ctx context.Context, req *LoginRequest) (*AuthResponse, error) {
	phone := normalizePhone(req.Phone)
	user, err := s.repo.FindByPhone(ctx, phone)
	if err != nil || !user.IsActive {
		return nil, ErrInvalidCredentials
	}
	if !verifyPassword(user.PasswordHash, req.Password) {
		return nil, ErrInvalidCredentials
	}
	accessToken, err := s.tokenGen.GenerateAccessToken(user)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}
	refreshToken, err := s.tokenGen.GenerateRefreshToken(user)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}
	s.logger.Info("user logged in", "user_id", user.ID)
	return &AuthResponse{AccessToken: accessToken, RefreshToken: refreshToken, ExpiresIn: s.cfg.JWT.AccessTTL, User: user}, nil
}

func (s *Service) SendOTP(ctx context.Context, phone string) error {
	phone = normalizePhone(phone)
	code := generateOTP()
	otp := &OTP{Code: code, ExpiresAt: time.Now().Add(5 * time.Minute), Attempts: 0}
	key := fmt.Sprintf("otp:%s", phone)
	if err := s.otpStore.Set(ctx, key, otp); err != nil {
		return fmt.Errorf("failed to store OTP: %w", err)
	}
	// Never log OTP codes — logs are a common credential leak path.
	s.logger.Info("OTP sent", "phone", maskPhone(phone))
	return nil
}

func (s *Service) VerifyOTP(ctx context.Context, phone string, code string) error {
	phone = normalizePhone(phone)
	key := fmt.Sprintf("otp:%s", phone)
	otp, err := s.otpStore.Get(ctx, key)
	if err != nil {
		return ErrInvalidOTP
	}
	if time.Now().After(otp.ExpiresAt) || otp.Attempts >= 5 {
		s.otpStore.Delete(ctx, key)
		return ErrInvalidOTP
	}
	if otp.Code != code {
		otp.Attempts++
		s.otpStore.Set(ctx, key, otp)
		return ErrInvalidOTP
	}
	user, err := s.repo.FindByPhone(ctx, phone)
	if err == nil {
		user.IsPhoneVerified = true
		user.UpdatedAt = time.Now()
		s.repo.Update(ctx, user)
	}
	s.otpStore.Delete(ctx, key)
	return nil
}

func (s *Service) RefreshToken(ctx context.Context, refreshToken string) (*AuthResponse, error) {
	claims, err := s.tokenGen.VerifyTokenOfType(refreshToken, TokenTypeRefresh)
	if err != nil {
		return nil, ErrTokenInvalid
	}
	user, err := s.repo.FindByID(ctx, claims.UserID)
	if err != nil || !user.IsActive {
		return nil, ErrUserNotFound
	}
	accessToken, _ := s.tokenGen.GenerateAccessToken(user)
	newRefreshToken, _ := s.tokenGen.GenerateRefreshToken(user)
	return &AuthResponse{AccessToken: accessToken, RefreshToken: newRefreshToken, ExpiresIn: s.cfg.JWT.AccessTTL, User: user}, nil
}

func (s *Service) GetProfile(ctx context.Context, userID uuid.UUID) (*User, error) {
	user, err := s.repo.FindByID(ctx, userID)
	if err != nil {
		return nil, ErrUserNotFound
	}
	return user, nil
}

func (s *Service) ChangePassword(ctx context.Context, userID uuid.UUID, oldPassword, newPassword string) error {
	user, err := s.repo.FindByID(ctx, userID)
	if err != nil {
		return ErrUserNotFound
	}
	if !verifyPassword(user.PasswordHash, oldPassword) {
		return ErrInvalidCredentials
	}
	hash, err := hashPassword(newPassword)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}
	return s.repo.UpdatePassword(ctx, userID, hash)
}

const (
	argonTime    = 3
	argonMemory  = 64 * 1024
	argonThreads = 4
	argonKeyLen  = 32
	argonSaltLen = 16
)

func hashPassword(password string) (string, error) {
	salt := make([]byte, argonSaltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	hash := argon2.IDKey([]byte(password), salt, argonTime, argonMemory, argonThreads, argonKeyLen)
	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Hash := base64.RawStdEncoding.EncodeToString(hash)
	return fmt.Sprintf("$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s", argonMemory, argonTime, argonThreads, b64Salt, b64Hash), nil
}

func verifyPassword(encodedHash, password string) bool {
	// PHC string format: $argon2id$v=19$m=MEMORY,t=TIME,p=THREADS$SALT$HASH
	parts := splitPHC(encodedHash)
	if len(parts) != 6 || parts[1] != "argon2id" {
		return false
	}
	var version, memory, timeVal, threads int
	if _, err := fmt.Sscanf(parts[2], "v=%d", &version); err != nil {
		return false
	}
	if _, err := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &memory, &timeVal, &threads); err != nil {
		return false
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return false
	}
	expectedHash, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil {
		return false
	}
	computedHash := argon2.IDKey([]byte(password), salt, uint32(timeVal), uint32(memory), uint8(threads), uint32(len(expectedHash)))
	return subtleConstantTimeCompare(computedHash, expectedHash)
}

func splitPHC(s string) []string {
	if s == "" {
		return nil
	}
	// split on $ keeping empty leading if starts with $
	out := make([]string, 0, 6)
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '$' {
			out = append(out, s[start:i])
			start = i + 1
		}
	}
	out = append(out, s[start:])
	return out
}

func subtleConstantTimeCompare(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	var result byte
	for i := 0; i < len(a); i++ {
		result |= a[i] ^ b[i]
	}
	return result == 0
}

func generateOTP() string {
	b := make([]byte, 4)
	rand.Read(b)
	code := (int(b[0])|int(b[1])<<8|int(b[2])<<16|int(b[3])<<24) % 1000000
	if code < 0 { code = -code }
	if code < 100000 { code += 100000 }
	return fmt.Sprintf("%d", code)
}

func maskPhone(phone string) string {
	if len(phone) < 4 {
		return "****"
	}
	return phone[:3] + "****" + phone[len(phone)-2:]
}

func normalizePhone(phone string) string {
	cleaned := ""
	for _, c := range phone {
		if c >= '0' && c <= '9' { cleaned += string(c) }
	}
	if len(cleaned) == 10 && cleaned[0] == '0' { cleaned = "254" + cleaned[1:] }
	if len(cleaned) == 9 { cleaned = "254" + cleaned }
	return cleaned
}

func toTitle(s string) string { return cases.Title(language.English).String(s) }
