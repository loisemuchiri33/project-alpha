package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/zeni-lending/backend/internal/auth"
	"github.com/zeni-lending/backend/internal/cache"
	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/internal/database"
	"github.com/zeni-lending/backend/internal/database/repositories"
	"github.com/zeni-lending/backend/internal/fraud"
	"github.com/zeni-lending/backend/internal/handlers"
	"github.com/zeni-lending/backend/internal/loan"
	"github.com/zeni-lending/backend/internal/payment"
	"github.com/zeni-lending/backend/internal/email"
	"github.com/zeni-lending/backend/internal/sms"
	"github.com/zeni-lending/backend/internal/router"
	"github.com/zeni-lending/backend/internal/workers"
	"github.com/zeni-lending/backend/pkg/logger"
)

func main() {
	cfg := config.Load()
	log := logger.NewLogger("zeni-api")
	if err := cfg.ValidateJWT(); err != nil {
		log.Error("invalid JWT configuration", "error", err)
		os.Exit(1)
	}
	log.Info("starting ZENI API server")

	var db *database.PostgresDB
	db, err := database.NewPostgresDB(cfg, log)
	if err != nil {
		log.Warn("database unavailable", "error", err)
		db = nil
	}

	var redisCache *cache.Cache
	redisCache, err = cache.NewCache(cfg, log)
	if err != nil {
		log.Warn("redis unavailable", "error", err)
		redisCache = nil
	}

	var userRepo *repositories.UserRepo
	var loanRepo *repositories.LoanRepo
	var auditRepo *repositories.AuditRepo
	var intentRepo *repositories.PaymentIntentRepo
	if db != nil {
		userRepo = repositories.NewUserRepo(db.Pool, log)
		loanRepo = repositories.NewLoanRepo(db.Pool, log)
		auditRepo = repositories.NewAuditRepo(db.Pool, log)
		intentRepo = repositories.NewPaymentIntentRepo(db.Pool, log)
	} else {
		userRepo = repositories.NewUserRepo(nil, log)
		loanRepo = repositories.NewLoanRepo(nil, log)
		auditRepo = repositories.NewAuditRepo(nil, log)
		intentRepo = repositories.NewPaymentIntentRepo(nil, log)
	}

	var otpStore auth.OTPStore
	if redisCache != nil {
		otpStore = cache.NewOTPStore(redisCache)
	} else {
		otpStore = newMemoryOTP()
		log.Warn("OTP store using in-memory fallback (not multi-instance safe)")
	}

	jwtSvc := auth.NewJWTManager(cfg)
	emailSvc := email.NewService(cfg.Email, log)
	authSvc := auth.NewService(cfg, log, userRepo, otpStore, jwtSvc)
	authSvc.SetEmailSender(emailSvc)
	loanEngine := loan.NewEngine(cfg, log, loanRepo)
	loanEngine.SetUserLookup(userRepo)
	mpesaSvc := payment.NewMpesaService(cfg, log)

	if redisCache == nil {
		log.Warn("fraud detector running with limited features (no redis)")
	}
	fraudDetect := fraud.NewDetector(log, redisCache)

	authH := handlers.NewAuthHandler(authSvc, log)
	loanH := handlers.NewLoanHandler(loanEngine, loanRepo, fraudDetect, log)
	payH := handlers.NewPaymentHandler(mpesaSvc, loanRepo, cfg, log)
	payH.SetEngine(loanEngine)
	payH.SetIntentRepo(intentRepo)
	kycH := handlers.NewKYCHandler(log)
	kycH.SetUserRepo(userRepo)
	userH := handlers.NewUserHandler(authSvc, log)
	adminH := handlers.NewAdminHandler(loanRepo, userRepo, loanEngine, log)
	adminH.SetAuditRepo(auditRepo)
	adminH.SetMpesa(mpesaSvc)
	smsSvc := sms.NewService(cfg.SMS, log)
	adminH.SetSMS(smsSvc)
	authH.SetAdminHandler(adminH)

	r := router.Setup(cfg.Server.Mode, &router.Dependencies{
		AuthHandler: authH, LoanHandler: loanH, PaymentHandler: payH,
		KYCHandler: kycH, UserHandler: userH, AdminHandler: adminH,
		TokenGen: jwtSvc,
	})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if db != nil {
		workers.NewLoanProcessor(log, loanEngine, loanRepo).Start(ctx)
	}

	srv := &http.Server{
		Addr:              ":" + cfg.Server.Port,
		Handler:           r,
		ReadTimeout:       time.Duration(cfg.Server.ReadTimeout) * time.Second,
		WriteTimeout:      time.Duration(cfg.Server.WriteTimeout) * time.Second,
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Info("server listening", "port", cfg.Server.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Info("shutting down")
	cancel()
	shctx, shcancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shcancel()
	_ = srv.Shutdown(shctx)
	if db != nil {
		db.Close()
	}
	if redisCache != nil {
		_ = redisCache.Close()
	}
	fmt.Println("ZENI API stopped")
}

type memoryOTPStore struct {
	data map[string]*auth.OTP
}

func newMemoryOTP() *memoryOTPStore {
	return &memoryOTPStore{data: make(map[string]*auth.OTP)}
}

func (m *memoryOTPStore) Set(_ context.Context, key string, otp *auth.OTP) error {
	m.data[key] = otp
	return nil
}
func (m *memoryOTPStore) Get(_ context.Context, key string) (*auth.OTP, error) {
	o, ok := m.data[key]
	if !ok {
		return nil, fmt.Errorf("otp not found")
	}
	return o, nil
}
func (m *memoryOTPStore) Delete(_ context.Context, key string) error {
	delete(m.data, key)
	return nil
}
