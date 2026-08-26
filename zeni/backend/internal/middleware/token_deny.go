package middleware

import (
	"sync"
	"time"
)

// In-memory access-token denylist (logout / forced revoke).
// Multi-replica deployments should replace this with Redis SET + TTL.
type tokenDenylist struct {
	mu   sync.RWMutex
	deny map[string]time.Time // jti -> expires
}

var globalDeny = &tokenDenylist{deny: make(map[string]time.Time)}

func init() {
	go func() {
		for {
			time.Sleep(2 * time.Minute)
			globalDeny.cleanup()
		}
	}()
}

// DenyToken marks a JWT ID as revoked until exp.
func DenyToken(jti string, exp time.Time) {
	if jti == "" {
		return
	}
	if exp.IsZero() {
		exp = time.Now().Add(24 * time.Hour)
	}
	globalDeny.mu.Lock()
	globalDeny.deny[jti] = exp
	globalDeny.mu.Unlock()
}

// IsTokenDenied reports whether jti was revoked.
func IsTokenDenied(jti string) bool {
	if jti == "" {
		return false
	}
	globalDeny.mu.RLock()
	exp, ok := globalDeny.deny[jti]
	globalDeny.mu.RUnlock()
	if !ok {
		return false
	}
	if time.Now().After(exp) {
		globalDeny.mu.Lock()
		delete(globalDeny.deny, jti)
		globalDeny.mu.Unlock()
		return false
	}
	return true
}

func (d *tokenDenylist) cleanup() {
	d.mu.Lock()
	defer d.mu.Unlock()
	now := time.Now()
	for k, exp := range d.deny {
		if now.After(exp) {
			delete(d.deny, k)
		}
	}
}
