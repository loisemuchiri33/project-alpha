package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/internal/database"
	"github.com/zeni-lending/backend/internal/database/repositories"
	"github.com/zeni-lending/backend/internal/loan"
	"github.com/zeni-lending/backend/internal/workers"
	"github.com/zeni-lending/backend/pkg/logger"
)

func main() {
	cfg := config.Load()
	log := logger.NewLogger("zeni-worker")
	db, err := database.NewPostgresDB(cfg, log)
	if err != nil {
		log.Error("db failed", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	loanRepo := repositories.NewLoanRepo(db.Pool, log)
	engine := loan.NewEngine(cfg, log, loanRepo)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	workers.NewLoanProcessor(log, engine, loanRepo).Start(ctx)
	log.Info("worker running")
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	cancel()
	log.Info("worker stopped")
}
