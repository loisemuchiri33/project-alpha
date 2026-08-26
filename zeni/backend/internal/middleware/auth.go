package middleware

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/zeni-lending/backend/internal/auth"
)

// AccessTokenVerifier verifies access tokens only (not refresh).
type AccessTokenVerifier interface {
	VerifyTokenOfType(tokenStr string, wantType string) (*auth.Claims, error)
}

func AuthRequired(tokenGen AccessTokenVerifier) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" || !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization token"})
			return
		}
		tokenStr := strings.TrimPrefix(header, "Bearer ")
		claims, err := tokenGen.VerifyTokenOfType(tokenStr, auth.TokenTypeAccess)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}
		if IsTokenDenied(claims.ID) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "session revoked"})
			return
		}
		c.Set("user_id", claims.UserID)
		c.Set("phone", claims.Phone)
		c.Set("role", claims.Role)
		c.Set("jti", claims.ID)
		if claims.ExpiresAt != nil {
			c.Set("token_exp", claims.ExpiresAt.Time)
		} else {
			c.Set("token_exp", time.Now().Add(15*time.Minute))
		}
		c.Next()
	}
}

// AdminRequired allows admin and superadmin (approve/reject + portfolio write).
func AdminRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, _ := c.Get("role")
		r, _ := role.(string)
		if r != "admin" && r != "superadmin" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "admin access required"})
			return
		}
		c.Next()
	}
}

// SuperAdminRequired is CEO-only (worker create/deactivate, activity).
func SuperAdminRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, _ := c.Get("role")
		r, _ := role.(string)
		if r != "superadmin" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "CEO access required"})
			return
		}
		c.Next()
	}
}

// StaffRequired allows agent, admin, superadmin (view queues / dashboard read).
func StaffRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, _ := c.Get("role")
		r, _ := role.(string)
		if !auth.IsStaffRole(r) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "staff access required"})
			return
		}
		c.Next()
	}
}
