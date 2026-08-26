package handlers

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/auth"
	"github.com/zeni-lending/backend/pkg/logger"
)

type KYCHandler struct {
	logger *logger.Logger
	users  auth.UserRepository
}

func NewKYCHandler(log *logger.Logger) *KYCHandler {
	return &KYCHandler{logger: log}
}

func (h *KYCHandler) SetUserRepo(r auth.UserRepository) {
	h.users = r
}

func (h *KYCHandler) Submit(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	var req struct {
		DocumentType string `json:"document_type" binding:"required"`
		DocumentURL  string `json:"document_url" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondValidationError(c, err)
		return
	}
	if h.users != nil {
		u, err := h.users.FindByID(c.Request.Context(), userID)
		if err == nil && u != nil {
			if u.KYCStatus != "verified" && u.KYCStatus != "approved" {
				u.KYCStatus = "pending"
				u.UpdatedAt = time.Now()
				_ = h.users.Update(c.Request.Context(), u)
			}
		}
	}
	h.logger.Info("kyc submitted", "user", userID, "type", req.DocumentType)
	RespondCreated(c, gin.H{
		"status":  "pending",
		"message": "KYC documents received for review",
		"user_id": userID,
	})
}

func (h *KYCHandler) Status(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	status := "not_submitted"
	limit := 0.0
	if h.users != nil {
		if u, err := h.users.FindByID(c.Request.Context(), userID); err == nil && u != nil {
			status = u.KYCStatus
			limit = u.LoanLimit
		}
	}
	RespondOK(c, gin.H{"user_id": userID, "kyc_status": status, "loan_limit": limit})
}
