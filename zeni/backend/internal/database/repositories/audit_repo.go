package repositories

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zeni-lending/backend/pkg/logger"
)

type AuditEntry struct {
	ID         uuid.UUID       `json:"id"`
	UserID     *uuid.UUID      `json:"user_id,omitempty"`
	WorkerName string          `json:"worker_name,omitempty"`
	Action     string          `json:"action"`
	Resource   string          `json:"resource"`
	ResourceID string          `json:"resource_id,omitempty"`
	IPAddress  string          `json:"ip_address,omitempty"`
	UserAgent  string          `json:"user_agent,omitempty"`
	Details    json.RawMessage `json:"details,omitempty"`
	CreatedAt  time.Time       `json:"created_at"`
}

type AuditRepo struct {
	pool   *pgxpool.Pool
	logger *logger.Logger
}

func NewAuditRepo(pool *pgxpool.Pool, log *logger.Logger) *AuditRepo {
	return &AuditRepo{pool: pool, logger: log}
}

func (r *AuditRepo) Log(ctx context.Context, e *AuditEntry) error {
	if r.pool == nil {
		return nil
	}
	if e.ID == uuid.Nil {
		e.ID = uuid.New()
	}
	if e.CreatedAt.IsZero() {
		e.CreatedAt = time.Now()
	}
	q := `INSERT INTO audit_logs (id, user_id, action, resource, resource_id, ip_address, user_agent, details, created_at)
		VALUES ($1,$2,$3,$4,$5,$6::inet,$7,$8,$9)`
	var uid interface{}
	if e.UserID != nil {
		uid = *e.UserID
	}
	var details interface{}
	if len(e.Details) > 0 {
		details = e.Details
	}
	ip := e.IPAddress
	if ip == "" {
		ip = "0.0.0.0"
	}
	_, err := r.pool.Exec(ctx, q, e.ID, uid, e.Action, e.Resource, nullStr(e.ResourceID), ip, nullStr(e.UserAgent), details, e.CreatedAt)
	return err
}

func (r *AuditRepo) List(ctx context.Context, limit int) ([]AuditEntry, error) {
	if r.pool == nil {
		return []AuditEntry{}, nil
	}
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	q := `
		SELECT a.id, a.user_id, COALESCE(u.first_name || ' ' || u.last_name, ''), a.action, a.resource,
			COALESCE(a.resource_id,''), COALESCE(host(a.ip_address)::text,''), COALESCE(a.user_agent,''),
			COALESCE(a.details, '{}'::jsonb), a.created_at
		FROM audit_logs a
		LEFT JOIN users u ON u.id = a.user_id
		ORDER BY a.created_at DESC
		LIMIT $1`
	rows, err := r.pool.Query(ctx, q, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AuditEntry
	for rows.Next() {
		var e AuditEntry
		var uid *uuid.UUID
		var details []byte
		if err := rows.Scan(&e.ID, &uid, &e.WorkerName, &e.Action, &e.Resource, &e.ResourceID, &e.IPAddress, &e.UserAgent, &details, &e.CreatedAt); err != nil {
			return nil, err
		}
		e.UserID = uid
		e.Details = details
		out = append(out, e)
	}
	if out == nil {
		out = []AuditEntry{}
	}
	return out, rows.Err()
}

func nullStr(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}
