package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"os"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Header("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'")
		c.Header("Permissions-Policy", "geolocation=(), microphone=(), camera=(), payment=()")
		c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload")
		c.Header("Cache-Control", "no-store")
		c.Header("Pragma", "no-cache")
		c.Header("X-Permitted-Cross-Domain-Policies", "none")
		// Do not advertise server stack
		c.Header("Server", "zeni")
		c.Next()
	}
}

func CORS() gin.HandlerFunc {
	fixed := map[string]struct{}{
		"https://zeni.co.ke":       {},
		"https://admin.zeni.co.ke": {},
		"https://app.zeni.co.ke":   {},
	}
	// Extra origins via env: CORS_ORIGINS=https://a.com,https://b.com
	if extra := os.Getenv("CORS_ORIGINS"); extra != "" {
		for _, o := range strings.Split(extra, ",") {
			o = strings.TrimSpace(o)
			if o != "" {
				fixed[o] = struct{}{}
			}
		}
	}
	devOK := os.Getenv("GIN_MODE") != "release"
	if devOK {
		fixed["http://localhost:3000"] = struct{}{}
		fixed["http://localhost:8080"] = struct{}{}
		fixed["http://127.0.0.1:3000"] = struct{}{}
		fixed["http://127.0.0.1:8080"] = struct{}{}
	}

	return cors.New(cors.Config{
		AllowOriginFunc: func(origin string) bool {
			// Non-browser clients (mobile apps, curl) send no Origin — allow the request path;
			// CORS only gates browser cross-origin reads.
			if origin == "" {
				return true
			}
			if _, ok := fixed[origin]; ok {
				return true
			}
			// Flutter web local ports during development only
			if devOK && (strings.HasPrefix(origin, "http://localhost:") || strings.HasPrefix(origin, "http://127.0.0.1:")) {
				return true
			}
			return false
		},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-Request-ID", "X-Device-ID", "X-Callback-Secret"},
		ExposeHeaders:    []string{"Content-Length", "X-Request-ID"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	})
}

func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		rid := c.GetHeader("X-Request-ID")
		if rid == "" {
			rid = generateID()
		}
		c.Set("request_id", rid)
		c.Header("X-Request-ID", rid)
		c.Next()
	}
}

func generateID() string {
	return time.Now().UTC().Format("20060102150405") + "-" + randomHex(8)
}

func randomHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		// extremely unlikely; fall back to timestamp slice
		return hex.EncodeToString([]byte(time.Now().Format("150405.000")))[:n]
	}
	return hex.EncodeToString(b)[:n]
}
