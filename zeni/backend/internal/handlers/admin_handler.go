package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/auth"
	"github.com/zeni-lending/backend/internal/database/repositories"
	"github.com/zeni-lending/backend/internal/loan"
	"github.com/zeni-lending/backend/internal/middleware"
	"github.com/zeni-lending/backend/internal/payment"
	"github.com/zeni-lending/backend/internal/sms"
	"github.com/zeni-lending/backend/pkg/logger"
)

type AdminStatsRepo interface {
	GetPortfolioStats(ctx context.Context) (map[string]interface{}, error)
	ListByStatus(ctx context.Context, status string, limit int) ([]*loan.Loan, error)
	FindByID(ctx context.Context, id uuid.UUID) (*loan.Loan, error)
}

type AdminUserRepo interface {
	CountActiveUsers(ctx context.Context) (int, error)
	CountPendingKYC(ctx context.Context) (int, error)
	ListStaff(ctx context.Context) ([]repositories.StaffMember, error)
	DeactivateStaff(ctx context.Context, userID uuid.UUID) error
	Create(ctx context.Context, user *auth.User) error
	FindByPhone(ctx context.Context, phone string) (*auth.User, error)
	FindByID(ctx context.Context, id uuid.UUID) (*auth.User, error)
	SetLastLogin(ctx context.Context, userID uuid.UUID) error
	Update(ctx context.Context, user *auth.User) error
}

type AdminAuditRepo interface {
	Log(ctx context.Context, e *repositories.AuditEntry) error
	List(ctx context.Context, limit int) ([]repositories.AuditEntry, error)
}

type AdminHandler struct {
	loanRepo  AdminStatsRepo
	userRepo  AdminUserRepo
	auditRepo AdminAuditRepo
	engine    *loan.Engine
	mpesa     *payment.MpesaService
	sms       *sms.Service
	logger    *logger.Logger
}

func NewAdminHandler(lr AdminStatsRepo, ur AdminUserRepo, engine *loan.Engine, log *logger.Logger) *AdminHandler {
	return &AdminHandler{loanRepo: lr, userRepo: ur, engine: engine, logger: log}
}

func (h *AdminHandler) SetAuditRepo(a AdminAuditRepo) { h.auditRepo = a }
func (h *AdminHandler) SetMpesa(m *payment.MpesaService) { h.mpesa = m }
func (h *AdminHandler) SetSMS(s *sms.Service) { h.sms = s }

func (h *AdminHandler) Dashboard(c *gin.Context) {
	if h.loanRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	stats, err := h.loanRepo.GetPortfolioStats(c.Request.Context())
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "stats failed")
		return
	}
	users, _ := h.userRepo.CountActiveUsers(c.Request.Context())
	pendingKYC, _ := h.userRepo.CountPendingKYC(c.Request.Context())
	out := gin.H{
		"users":           users,
		"pending_kyc":     pendingKYC,
		"active_loans":    stats["active_loans"],
		"total_disbursed": stats["total_disbursed"],
		"total_collected": stats["total_collected"],
		"default_rate":    stats["default_rate"],
		"pending_loans":   stats["pending_loans"],
		"overdue_loans":   stats["overdue_loans"],
		"overdue_amount":  stats["overdue_amount"],
		"loans":           stats,
	}
	RespondOK(c, out)
}

func (h *AdminHandler) Health(c *gin.Context) {
	RespondOK(c, gin.H{"status": "healthy", "version": "1.0.0"})
}

func (h *AdminHandler) ListLoans(c *gin.Context) {
	if h.loanRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	status := c.DefaultQuery("status", "pending")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	items, err := h.loanRepo.ListByStatus(c.Request.Context(), status, limit)
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to list loans")
		return
	}
	if items == nil {
		items = []*loan.Loan{}
	}
	RespondOK(c, gin.H{"loans": items, "status": status, "count": len(items)})
}

// ApproveLoan underwrites only — does NOT disburse funds.
func (h *AdminHandler) ApproveLoan(c *gin.Context) {
	if h.engine == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid loan id")
		return
	}
	approver := c.MustGet("user_id").(uuid.UUID)
	l, err := h.engine.Approve(c.Request.Context(), id, approver)
	if err != nil {
		RespondError(c, http.StatusBadRequest, err.Error())
		return
	}
	h.logger.Info("admin approved loan", "loan_id", id, "admin", approver)
	h.writeAudit(c, &approver, "approve_loan", "loan", id.String(), nil)
	RespondOK(c, gin.H{"loan": l, "message": "loan approved; call disburse to send funds"})
}

// DisburseLoan triggers B2C for an approved loan (admin/superadmin only).
func (h *AdminHandler) DisburseLoan(c *gin.Context) {
	if h.engine == nil || h.userRepo == nil || h.loanRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid loan id")
		return
	}
	actor := c.MustGet("user_id").(uuid.UUID)
	var body struct {
		Phone string `json:"phone"`
	}
	_ = c.ShouldBindJSON(&body)

	ln, err := h.loanRepo.FindByID(c.Request.Context(), id)
	if err != nil || ln == nil {
		RespondError(c, http.StatusNotFound, "loan not found")
		return
	}
	if ln.Status != "approved" && ln.Status != "disbursement_failed" {
		RespondError(c, http.StatusBadRequest, "loan must be approved before disbursement")
		return
	}
	borrower, err := h.userRepo.FindByID(c.Request.Context(), ln.UserID)
	if err != nil || borrower == nil {
		RespondError(c, http.StatusBadRequest, "borrower not found")
		return
	}
	phone := borrower.Phone
	if body.Phone != "" {
		phone = normalizePhoneDigits(body.Phone)
		if phone != borrower.Phone {
			RespondError(c, http.StatusBadRequest, "disbursement phone must match registered borrower phone")
			return
		}
	}
	if h.mpesa == nil {
		RespondError(c, http.StatusServiceUnavailable, "payment service unavailable")
		return
	}
	// Dual-control: large disbursements require a second approver different from original underwriter.
	const dualControlThreshold = 20000.0 // KES
	if ln.Amount >= dualControlThreshold && ln.ApprovedBy != nil && *ln.ApprovedBy == actor {
		RespondError(c, http.StatusForbidden, "amounts >= KES 20,000 require a different admin to disburse (maker-checker)")
		return
	}

	originatorConversationID := "ZENI" + ln.ID.String()[:8]
	if err := h.mpesa.DisburseFunds(c.Request.Context(), phone, ln.Amount, "ZENI loan "+ln.ID.String()[:8]); err != nil {
		h.logger.Error("b2c disburse failed", "error", err, "loan", id)
		_, _ = h.engine.MarkDisbursementFailed(c.Request.Context(), id, err.Error())
		h.writeAudit(c, &actor, "disburse_loan_failed", "loan", id.String(), map[string]interface{}{"error": err.Error()})
		RespondError(c, http.StatusBadGateway, "disbursement failed")
		return
	}

	// Tala-class: do NOT mark active until B2C ResultURL confirms success.
	// Move to disbursement_pending so callbacks can finalize the ledger.
	pending, err := h.engine.MarkDisbursementPending(c.Request.Context(), id)
	if err != nil {
		RespondError(c, http.StatusBadRequest, err.Error())
		return
	}
	h.writeAudit(c, &actor, "disburse_loan_initiated", "loan", id.String(), map[string]interface{}{
		"amount": ln.Amount, "phone": phone, "originator_conversation_id": originatorConversationID,
	})
	RespondOK(c, gin.H{
		"loan":    pending,
		"message": "disbursement initiated; loan becomes active only after M-Pesa B2C success callback",
	})
}

func (h *AdminHandler) RejectLoan(c *gin.Context) {
	if h.engine == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid loan id")
		return
	}
	var body struct {
		Reason string `json:"reason"`
	}
	_ = c.ShouldBindJSON(&body)
	rejector := c.MustGet("user_id").(uuid.UUID)
	l, err := h.engine.Reject(c.Request.Context(), id, rejector, body.Reason)
	if err != nil {
		RespondError(c, http.StatusBadRequest, err.Error())
		return
	}
	h.logger.Info("admin rejected loan", "loan_id", id, "admin", rejector)
	h.writeAudit(c, &rejector, "reject_loan", "loan", id.String(), map[string]interface{}{"reason": body.Reason})
	RespondOK(c, l)
}

// SendPaymentReminder lets staff SMS a borrower about an outstanding loan.
// Allowed for admin + superadmin. Audited.
func (h *AdminHandler) SendPaymentReminder(c *gin.Context) {
	if h.loanRepo == nil || h.userRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	if h.sms == nil {
		RespondError(c, http.StatusServiceUnavailable, "SMS service unavailable")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid loan id")
		return
	}
	var body struct {
		Message string `json:"message"` // optional custom text
	}
	_ = c.ShouldBindJSON(&body)

	ln, err := h.loanRepo.FindByID(c.Request.Context(), id)
	if err != nil || ln == nil {
		RespondError(c, http.StatusNotFound, "loan not found")
		return
	}
	// Only remind on live or overdue loans
	status := strings.ToLower(ln.Status)
	if status != "active" && status != "overdue" && status != "approved" {
		RespondError(c, http.StatusBadRequest, "reminders only for active, overdue or approved loans")
		return
	}

	borrower, err := h.userRepo.FindByID(c.Request.Context(), ln.UserID)
	if err != nil || borrower == nil {
		RespondError(c, http.StatusBadRequest, "borrower not found")
		return
	}

	amountDue := ln.TotalRepayment - ln.AmountPaid
	if amountDue < 0 {
		amountDue = 0
	}
	name := strings.TrimSpace(borrower.FirstName + " " + borrower.LastName)
	msg := sms.PaymentReminderMessage(name, amountDue, ln.DueDate, strings.TrimSpace(body.Message))

	if err := h.sms.Send(c.Request.Context(), borrower.Phone, msg); err != nil {
		h.logger.Error("payment reminder SMS failed", "loan_id", id, "error", err)
		RespondError(c, http.StatusBadGateway, "failed to send SMS")
		return
	}

	actor := c.MustGet("user_id").(uuid.UUID)
	h.writeAudit(c, &actor, "send_payment_reminder", "loan", id.String(), map[string]interface{}{
		"phone":      borrower.Phone,
		"amount_due": amountDue,
		"custom":     body.Message != "",
	})
	RespondOK(c, gin.H{
		"message":    "reminder sent",
		"loan_id":    id,
		"phone":      borrower.Phone,
		"amount_due": amountDue,
	})
}



func (h *AdminHandler) ListWorkers(c *gin.Context) {
	if h.userRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	items, err := h.userRepo.ListStaff(c.Request.Context())
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to list workers")
		return
	}
	RespondOK(c, gin.H{"workers": items, "count": len(items)})
}

func (h *AdminHandler) CreateWorker(c *gin.Context) {
	if h.userRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	var body struct {
		Phone     string `json:"phone" binding:"required"`
		Password  string `json:"password" binding:"required,min=8"`
		FirstName string `json:"first_name" binding:"required"`
		LastName  string `json:"last_name" binding:"required"`
		Email     string `json:"email" binding:"required,email"`
		Role      string `json:"role"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		RespondValidationError(c, err)
		return
	}
	email := strings.ToLower(strings.TrimSpace(body.Email))
	if email == "" || !strings.Contains(email, "@") {
		RespondError(c, http.StatusBadRequest, "a valid email is required for all staff accounts")
		return
	}
	role := strings.ToLower(strings.TrimSpace(body.Role))
	if role == "" {
		role = "admin"
	}
	if role != "admin" && role != "agent" {
		RespondError(c, http.StatusBadRequest, "role must be admin or agent")
		return
	}
	phone := normalizePhoneDigits(body.Phone)
	if existing, err := h.userRepo.FindByPhone(c.Request.Context(), phone); err == nil && existing != nil {
		RespondError(c, http.StatusConflict, "a user with this phone already exists")
		return
	}
	hash, err := auth.HashPassword(body.Password)
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to hash password")
		return
	}
	now := time.Now()
	user := &auth.User{
		ID: uuid.New(), Phone: phone, Email: email,
		FirstName: body.FirstName, LastName: body.LastName,
		PasswordHash: hash, Role: role, KYCStatus: "not_submitted",
		CreditScore: 500, RiskLevel: "medium", IsActive: true,
		IsPhoneVerified: true, CreatedAt: now, UpdatedAt: now,
	}
	if err := h.userRepo.Create(c.Request.Context(), user); err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to create worker")
		return
	}
	actor := c.MustGet("user_id").(uuid.UUID)
	h.writeAudit(c, &actor, "create_worker", "user", user.ID.String(), map[string]interface{}{
		"phone": phone, "role": role, "name": body.FirstName + " " + body.LastName,
	})
	RespondCreated(c, gin.H{"worker": gin.H{
		"id": user.ID, "phone": user.Phone, "first_name": user.FirstName,
		"last_name": user.LastName, "role": user.Role, "email": user.Email,
	}})
}

func (h *AdminHandler) DeactivateWorker(c *gin.Context) {
	if h.userRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid worker id")
		return
	}
	actor := c.MustGet("user_id").(uuid.UUID)
	if id == actor {
		RespondError(c, http.StatusBadRequest, "cannot deactivate your own account")
		return
	}
	if err := h.userRepo.DeactivateStaff(c.Request.Context(), id); err != nil {
		RespondError(c, http.StatusBadRequest, err.Error())
		return
	}
	h.writeAudit(c, &actor, "deactivate_worker", "user", id.String(), nil)
	RespondOK(c, gin.H{"message": "worker deactivated"})
}

func (h *AdminHandler) ListActivity(c *gin.Context) {
	if h.auditRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	limit := 200
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 500 {
			limit = n
		}
	}
	actionFilter := strings.TrimSpace(c.Query("action"))
	items, err := h.auditRepo.List(c.Request.Context(), limit)
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to load activity")
		return
	}
	if actionFilter != "" {
		filtered := make([]repositories.AuditEntry, 0, len(items))
		for _, it := range items {
			if strings.EqualFold(it.Action, actionFilter) {
				filtered = append(filtered, it)
			}
		}
		items = filtered
	}
	RespondOK(c, gin.H{"activity": items, "count": len(items)})
}

// ListSessions returns the latest login/logout events per staff member for the CEO desk.
func (h *AdminHandler) ListSessions(c *gin.Context) {
	if h.auditRepo == nil || h.userRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	staff, err := h.userRepo.ListStaff(c.Request.Context())
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to list workers")
		return
	}
	items, err := h.auditRepo.List(c.Request.Context(), 500)
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to load sessions")
		return
	}
	type sess struct {
		UserID       string     `json:"user_id"`
		WorkerName   string     `json:"worker_name"`
		Role         string     `json:"role"`
		Phone        string     `json:"phone"`
		IsActive     bool       `json:"is_active"`
		LastLoginAt  *time.Time `json:"last_login_at,omitempty"`
		LastLogoutAt *time.Time `json:"last_logout_at,omitempty"`
		LastLoginIP  string     `json:"last_login_ip,omitempty"`
		LastLogoutIP string     `json:"last_logout_ip,omitempty"`
		Status       string     `json:"status"` // online | offline | never
	}
	byID := map[string]*sess{}
	for _, w := range staff {
		s := &sess{
			UserID: w.ID.String(), WorkerName: strings.TrimSpace(w.FirstName + " " + w.LastName),
			Role: w.Role, Phone: w.Phone, IsActive: w.IsActive, LastLoginAt: w.LastLogin, Status: "never",
		}
		if w.LastLogin != nil {
			s.Status = "offline"
		}
		byID[w.ID.String()] = s
	}
	for _, a := range items {
		if a.UserID == nil {
			continue
		}
		id := a.UserID.String()
		s, ok := byID[id]
		if !ok {
			continue
		}
		switch a.Action {
		case "login":
			if s.LastLoginAt == nil || a.CreatedAt.After(*s.LastLoginAt) {
				t := a.CreatedAt
				s.LastLoginAt = &t
				s.LastLoginIP = a.IPAddress
			}
		case "logout":
			if s.LastLogoutAt == nil || a.CreatedAt.After(*s.LastLogoutAt) {
				t := a.CreatedAt
				s.LastLogoutAt = &t
				s.LastLogoutIP = a.IPAddress
			}
		}
	}
	out := make([]sess, 0, len(byID))
	for _, s := range byID {
		if s.LastLoginAt != nil && (s.LastLogoutAt == nil || s.LastLoginAt.After(*s.LastLogoutAt)) {
			// Logged in more recently than last logout → treat as online (best-effort).
			s.Status = "online"
		} else if s.LastLoginAt != nil {
			s.Status = "offline"
		} else {
			s.Status = "never"
		}
		out = append(out, *s)
	}
	RespondOK(c, gin.H{"sessions": out, "count": len(out)})
}

func (h *AdminHandler) Logout(c *gin.Context) {
	actor := c.MustGet("user_id").(uuid.UUID)
	// Revoke current access token so stolen copies stop working after sign-out.
	if jti, ok := c.Get("jti"); ok {
		if j, _ := jti.(string); j != "" {
			exp := time.Now().Add(24 * time.Hour)
			if te, ok := c.Get("token_exp"); ok {
				if t, ok := te.(time.Time); ok {
					exp = t
				}
			}
			middleware.DenyToken(j, exp)
		}
	}
	h.writeAudit(c, &actor, "logout", "session", "", map[string]interface{}{
		"event": "sign_out",
	})
	RespondOK(c, gin.H{"message": "logged out"})
}

// ReviewKYC lets admin/superadmin set borrower KYC status.
func (h *AdminHandler) ReviewKYC(c *gin.Context) {
	if h.userRepo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid user id")
		return
	}
	var body struct {
		Status    string  `json:"status" binding:"required"`
		LoanLimit float64 `json:"loan_limit"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		RespondValidationError(c, err)
		return
	}
	status := strings.ToLower(strings.TrimSpace(body.Status))
	switch status {
	case "verified", "approved", "rejected", "pending":
	default:
		RespondError(c, http.StatusBadRequest, "status must be verified, approved, rejected, or pending")
		return
	}
	u, err := h.userRepo.FindByID(c.Request.Context(), id)
	if err != nil || u == nil {
		RespondError(c, http.StatusNotFound, "user not found")
		return
	}
	u.KYCStatus = status
	if body.LoanLimit > 0 {
		u.LoanLimit = body.LoanLimit
	}
	if err := h.userRepo.Update(c.Request.Context(), u); err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to update kyc")
		return
	}
	actor := c.MustGet("user_id").(uuid.UUID)
	h.writeAudit(c, &actor, "review_kyc", "user", id.String(), map[string]interface{}{"status": status, "loan_limit": u.LoanLimit})
	RespondOK(c, gin.H{"user_id": id, "kyc_status": status, "loan_limit": u.LoanLimit})
}

func (h *AdminHandler) RecordLogin(ctx context.Context, userID uuid.UUID, ip, ua string) {
	if h.userRepo != nil {
		_ = h.userRepo.SetLastLogin(ctx, userID)
	}
	if h.auditRepo == nil {
		return
	}
	details, _ := json.Marshal(map[string]interface{}{"event": "sign_in"})
	_ = h.auditRepo.Log(ctx, &repositories.AuditEntry{
		UserID: &userID, Action: "login", Resource: "session",
		IPAddress: ip, UserAgent: ua, Details: details,
	})
}

// RecordFailedLogin logs failed staff credential attempts (no user id when unknown).
func (h *AdminHandler) RecordFailedLogin(ctx context.Context, identifier, ip, ua string) {
	if h.auditRepo == nil {
		return
	}
	details, _ := json.Marshal(map[string]interface{}{
		"event": "failed_login", "identifier": maskIdentifier(identifier),
	})
	_ = h.auditRepo.Log(ctx, &repositories.AuditEntry{
		Action: "login_failed", Resource: "session",
		IPAddress: ip, UserAgent: ua, Details: details,
	})
}

func maskIdentifier(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	if strings.Contains(s, "@") {
		parts := strings.SplitN(s, "@", 2)
		local := parts[0]
		if len(local) <= 2 {
			return "**@" + parts[1]
		}
		return local[:2] + "***@" + parts[1]
	}
	if len(s) <= 4 {
		return "****"
	}
	return s[:3] + "****" + s[len(s)-2:]
}

func (h *AdminHandler) writeAudit(c *gin.Context, userID *uuid.UUID, action, resource, resourceID string, details map[string]interface{}) {
	if h.auditRepo == nil {
		return
	}
	var raw json.RawMessage
	if details != nil {
		raw, _ = json.Marshal(details)
	}
	_ = h.auditRepo.Log(c.Request.Context(), &repositories.AuditEntry{
		UserID: userID, Action: action, Resource: resource, ResourceID: resourceID,
		IPAddress: c.ClientIP(), UserAgent: c.GetHeader("User-Agent"), Details: raw,
	})
}

func normalizePhoneDigits(phone string) string {
	cleaned := ""
	for _, ch := range phone {
		if ch >= '0' && ch <= '9' {
			cleaned += string(ch)
		}
	}
	if len(cleaned) == 10 && cleaned[0] == '0' {
		cleaned = "254" + cleaned[1:]
	}
	if len(cleaned) == 9 {
		cleaned = "254" + cleaned
	}
	return cleaned
}
