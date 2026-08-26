package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type rateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	rate     int
	window   time.Duration
}

type visitor struct {
	count       int
	windowStart time.Time
}

// RateLimit is a fixed-window limiter per ClientIP (not multi-replica safe — use Redis in prod scale-out).
func RateLimit(requestsPerWindow int, window time.Duration) gin.HandlerFunc {
	rl := &rateLimiter{
		visitors: make(map[string]*visitor),
		rate:     requestsPerWindow,
		window:   window,
	}
	go rl.cleanup()
	return func(c *gin.Context) {
		ip := c.ClientIP()
		now := time.Now()
		rl.mu.Lock()
		v, exists := rl.visitors[ip]
		if !exists || now.Sub(v.windowStart) >= rl.window {
			rl.visitors[ip] = &visitor{count: 1, windowStart: now}
			rl.mu.Unlock()
			c.Next()
			return
		}
		v.count++
		if v.count > rl.rate {
			retry := int(rl.window.Seconds() - now.Sub(v.windowStart).Seconds())
			if retry < 1 {
				retry = 1
			}
			rl.mu.Unlock()
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": "rate limit exceeded", "retry_after": retry,
			})
			return
		}
		rl.mu.Unlock()
		c.Next()
	}
}

func (rl *rateLimiter) cleanup() {
	for {
		time.Sleep(time.Minute)
		rl.mu.Lock()
		now := time.Now()
		for ip, v := range rl.visitors {
			if now.Sub(v.windowStart) > rl.window*2 {
				delete(rl.visitors, ip)
			}
		}
		rl.mu.Unlock()
	}
}
