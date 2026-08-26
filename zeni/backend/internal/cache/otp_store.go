package cache

import (
	"context"
	"fmt"
	"time"

	"github.com/zeni-lending/backend/internal/auth"
)

type OTPStore struct{ cache *Cache }

func NewOTPStore(cache *Cache) *OTPStore { return &OTPStore{cache: cache} }

func (s *OTPStore) Set(ctx context.Context, key string, otp *auth.OTP) error {
	ttl := time.Until(otp.ExpiresAt)
	if ttl <= 0 {
		ttl = 5 * time.Minute
	}
	return s.cache.Set(ctx, key, otp, ttl)
}

func (s *OTPStore) Get(ctx context.Context, key string) (*auth.OTP, error) {
	var otp auth.OTP
	if err := s.cache.Get(ctx, key, &otp); err != nil {
		return nil, fmt.Errorf("otp not found: %w", err)
	}
	return &otp, nil
}

func (s *OTPStore) Delete(ctx context.Context, key string) error {
	return s.cache.Delete(ctx, key)
}
