package router

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/zeni-lending/backend/internal/auth"
	"github.com/zeni-lending/backend/internal/handlers"
	"github.com/zeni-lending/backend/internal/middleware"
)

type Dependencies struct {
	AuthHandler    *handlers.AuthHandler
	LoanHandler    *handlers.LoanHandler
	PaymentHandler *handlers.PaymentHandler
	KYCHandler     *handlers.KYCHandler
	UserHandler    *handlers.UserHandler
	AdminHandler   *handlers.AdminHandler
	TokenGen       auth.TokenGenerator
}

func Setup(mode string, deps *Dependencies) *gin.Engine {
	gin.SetMode(mode)
	r := gin.New()
	r.Use(gin.Recovery())
	if mode != "release" {
		r.Use(gin.Logger())
	}
	r.Use(middleware.SecurityHeaders())
	r.Use(middleware.CORS())
	r.Use(middleware.RequestID())
	// Global ceiling — auth routes use a tighter limiter below.
	r.Use(middleware.RateLimit(120, time.Minute))

	// Minimal liveness — no version, stack, or dependency leakage.
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})
	r.GET("/ready", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ready"})
	})
	// No route listing / debug endpoints in any mode.
	r.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
	})
	r.NoMethod(func(c *gin.Context) {
		c.JSON(http.StatusMethodNotAllowed, gin.H{"error": "method not allowed"})
	})

	v1 := r.Group("/api/v1")
	{
		authG := v1.Group("/auth")
		// Brute-force resistance on credential endpoints
		authG.Use(middleware.RateLimit(12, time.Minute))
		{
			authG.POST("/register", deps.AuthHandler.Register)
			authG.POST("/login", deps.AuthHandler.Login)
			authG.POST("/staff/verify-email-otp", middleware.RateLimit(8, time.Minute), deps.AuthHandler.VerifyStaffEmailOTP)
			authG.POST("/otp/send", middleware.RateLimit(5, time.Minute), deps.AuthHandler.SendOTP)
			authG.POST("/otp/verify", deps.AuthHandler.VerifyOTP)
			authG.POST("/refresh", deps.AuthHandler.RefreshToken)
		}

		// Public payment callback (guarded by MPESA_CALLBACK_SECRET in handler)
		v1.POST("/payments/callback", middleware.RateLimit(60, time.Minute), deps.PaymentHandler.Callback)

		protected := v1.Group("")
		protected.Use(middleware.AuthRequired(deps.TokenGen))
		{
			protected.GET("/user/profile", deps.UserHandler.GetProfile)
			protected.POST("/auth/change-password", deps.AuthHandler.ChangePassword)

			protected.POST("/loans", deps.LoanHandler.Apply)
			protected.GET("/loans", deps.LoanHandler.List)
			protected.GET("/loans/:id", deps.LoanHandler.Get)

			protected.POST("/payments/stk", deps.PaymentHandler.STKPush)

			protected.POST("/kyc", deps.KYCHandler.Submit)
			protected.GET("/kyc/status", deps.KYCHandler.Status)
		}

		// Staff ops: admin + superadmin only — never public
		admin := v1.Group("/admin")
		admin.Use(middleware.AuthRequired(deps.TokenGen), middleware.AdminRequired())
		admin.Use(middleware.RateLimit(90, time.Minute))
		{
			admin.GET("/dashboard", deps.AdminHandler.Dashboard)
			admin.GET("/health", deps.AdminHandler.Health)
			admin.GET("/loans", deps.AdminHandler.ListLoans)
			admin.POST("/loans/:id/approve", deps.AdminHandler.ApproveLoan)
			admin.POST("/loans/:id/reject", deps.AdminHandler.RejectLoan)
			admin.POST("/loans/:id/remind", deps.AdminHandler.SendPaymentReminder)
			admin.POST("/loans/:id/disburse", deps.AdminHandler.DisburseLoan)
			admin.POST("/users/:id/kyc", deps.AdminHandler.ReviewKYC)

			admin.GET("/workers", deps.AdminHandler.ListWorkers)
			admin.POST("/logout", deps.AdminHandler.Logout)

			// CEO only — worker lifecycle + full activity (login/logout trail)
			ceo := admin.Group("")
			ceo.Use(middleware.SuperAdminRequired())
			{
				ceo.POST("/workers", deps.AdminHandler.CreateWorker)
				ceo.POST("/workers/:id/deactivate", deps.AdminHandler.DeactivateWorker)
				ceo.GET("/activity", deps.AdminHandler.ListActivity)
				ceo.GET("/sessions", deps.AdminHandler.ListSessions)
			}
		}
	}
	return r
}
