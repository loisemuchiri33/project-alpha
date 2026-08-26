package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/fraud"
	"github.com/zeni-lending/backend/internal/loan"
	"github.com/zeni-lending/backend/pkg/logger"
)

type LoanHandler struct {
	engine *loan.Engine
	repo   loan.LoanRepository
	fraud  *fraud.Detector
	logger *logger.Logger
}

func NewLoanHandler(engine *loan.Engine, repo loan.LoanRepository, det *fraud.Detector, log *logger.Logger) *LoanHandler {
	return &LoanHandler{engine: engine, repo: repo, fraud: det, logger: log}
}

func (h *LoanHandler) Apply(c *gin.Context) {
	uid := c.MustGet("user_id").(uuid.UUID)
	var body struct {
		Amount       float64 `json:"amount" binding:"required,gt=0"`
		DurationDays int     `json:"duration_days"` // ignored if omitted; product is always 30 days
		Purpose      string  `json:"purpose"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		RespondError(c, http.StatusBadRequest, "invalid loan application")
		return
	}
	// Product rule: all loans are 30-day only
	body.DurationDays = loan.FixedLoanTenorDays

	if h.fraud != nil {
		risk := h.fraud.Assess(c.Request.Context(), &fraud.Event{
			UserID:    uid.String(),
			EventType: "loan_apply",
			Amount:    body.Amount,
			IPAddress: c.ClientIP(),
		})
		if risk.Action == "reject" || risk.Level == "critical" {
			RespondError(c, http.StatusForbidden, "application blocked by risk controls")
			return
		}
	}

	app := &loan.Application{
		UserID:       uid,
		Amount:       body.Amount,
		DurationDays: loan.FixedLoanTenorDays,
		Purpose:      body.Purpose,
	}

	l, err := h.engine.Apply(c.Request.Context(), app)
	if err != nil {
		RespondError(c, http.StatusBadRequest, err.Error())
		return
	}
	RespondCreated(c, l)
}

func (h *LoanHandler) List(c *gin.Context) {
	if h.repo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	uid := c.MustGet("user_id").(uuid.UUID)
	loans, err := h.repo.FindByUserID(c.Request.Context(), uid)
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to list loans")
		return
	}
	RespondOK(c, loans)
}

func (h *LoanHandler) Get(c *gin.Context) {
	if h.repo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid loan id")
		return
	}
	l, err := h.repo.FindByID(c.Request.Context(), id)
	if err != nil {
		RespondError(c, http.StatusNotFound, "loan not found")
		return
	}
	userID := c.MustGet("user_id").(uuid.UUID)
	if l.UserID != userID {
		role, _ := c.Get("role")
		if role != "admin" && role != "superadmin" && role != "agent" {
			RespondError(c, http.StatusForbidden, "forbidden")
			return
		}
	}
	RespondOK(c, l)
}

func (h *LoanHandler) Stats(c *gin.Context) {
	if h.repo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	uid := c.MustGet("user_id").(uuid.UUID)
	stats, err := h.repo.GetUserLoanStats(c.Request.Context(), uid)
	if err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to load stats")
		return
	}
	RespondOK(c, stats)
}
