package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/pkg/logger"
)

type PostgresDB struct {
	Pool   *pgxpool.Pool
	config *config.Config
	logger *logger.Logger
}

func NewPostgresDB(cfg *config.Config, log *logger.Logger) (*PostgresDB, error) {
	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s&pool_max_conns=%d&pool_min_conns=%d",
		cfg.Database.User, cfg.Database.Password, cfg.Database.Host,
		cfg.Database.Port, cfg.Database.Name, cfg.Database.SSLMode,
		cfg.Database.MaxOpenConns, cfg.Database.MaxIdleConns,
	)
	poolConfig, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse db config: %w", err)
	}
	poolConfig.MaxConns = int32(cfg.Database.MaxOpenConns)
	poolConfig.MinConns = int32(cfg.Database.MaxIdleConns)
	poolConfig.MaxConnLifetime = 30 * time.Minute
	poolConfig.MaxConnIdleTime = 10 * time.Minute
	poolConfig.HealthCheckPeriod = 30 * time.Second

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	log.Info("connected to PostgreSQL", "host", cfg.Database.Host, "db", cfg.Database.Name)

	db := &PostgresDB{Pool: pool, config: cfg, logger: log}
	if err := db.runMigrations(); err != nil {
		log.Warn("migration warning", "error", err)
	}
	return db, nil
}

func (db *PostgresDB) Close() {
	if db.Pool != nil {
		db.Pool.Close()
		db.logger.Info("postgresql pool closed")
	}
}

func (db *PostgresDB) runMigrations() error {
	sqlDB := stdlib.OpenDBFromPool(db.Pool)
	defer sqlDB.Close()
	if err := goose.SetDialect("postgres"); err != nil {
		return err
	}
	return goose.Up(sqlDB, db.config.Database.MigrationsPath)
}

func (db *PostgresDB) HealthCheck(ctx context.Context) map[string]interface{} {
	stats := db.Pool.Stat()
	return map[string]interface{}{
		"status":               "healthy",
		"total_connections":    stats.TotalConns(),
		"idle_connections":     stats.IdleConns(),
		"acquired_connections": stats.AcquiredConns(),
		"max_connections":      stats.MaxConns(),
	}
}
