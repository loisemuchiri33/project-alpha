package auth

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/config"
)

const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"
)

type JWTManager struct {
	cfg *config.Config
}

func NewJWTManager(cfg *config.Config) *JWTManager {
	return &JWTManager{cfg: cfg}
}

func roleOrDefault(user *User) string {
	if user != nil && user.Role != "" {
		return user.Role
	}
	return "user"
}

func (m *JWTManager) GenerateAccessToken(user *User) (string, error) {
	claims := Claims{
		UserID:    user.ID,
		Phone:     user.Phone,
		Role:      roleOrDefault(user),
		TokenType: TokenTypeAccess,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(m.cfg.JWT.AccessTTL) * time.Second)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    m.cfg.JWT.Issuer,
			Subject:   user.ID.String(),
			ID:        uuid.New().String(),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(m.cfg.JWT.Secret))
}

func (m *JWTManager) GenerateRefreshToken(user *User) (string, error) {
	claims := Claims{
		UserID:    user.ID,
		Phone:     user.Phone,
		Role:      roleOrDefault(user),
		TokenType: TokenTypeRefresh,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(m.cfg.JWT.RefreshTTL) * time.Second)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    m.cfg.JWT.Issuer,
			Subject:   user.ID.String(),
			ID:        uuid.New().String(),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(m.cfg.JWT.Secret))
}

func (m *JWTManager) VerifyToken(tokenStr string) (*Claims, error) {
	return m.VerifyTokenOfType(tokenStr, "")
}

// VerifyTokenOfType parses a JWT and optionally requires TokenType ("access" | "refresh").
func (m *JWTManager) VerifyTokenOfType(tokenStr string, wantType string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(m.cfg.JWT.Secret), nil
	})
	if err != nil {
		return nil, ErrTokenInvalid
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, ErrTokenInvalid
	}
	if wantType != "" {
		// Legacy tokens without typ: treat missing as access only when wantType is access.
		got := claims.TokenType
		if got == "" && wantType == TokenTypeAccess {
			got = TokenTypeAccess
		}
		if got != wantType {
			return nil, ErrTokenInvalid
		}
	}
	return claims, nil
}
