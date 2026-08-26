package handlers

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/auth"
	"github.com/zeni-lending/backend/pkg/logger"
)

type AuthHandler struct {
	svc    *auth.Service
	logger *logger.Logger
	adminH *AdminHandler
}

func NewAuthHandler(svc *auth.Service, log *logger.Logger) *AuthHandler {
	return &AuthHandler{svc: svc, logger: log}
}

func (h *AuthHandler) SetAdminHandler(a *AdminHandler) {
	h.adminH = a
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req auth.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondValidationError(c, err)
		return
	}
	user, err := h.svc.Register(c.Request.Context(), &req)
	if err != nil {
		if errors.Is(err, auth.ErrUserExists) {
			RespondError(c, http.StatusConflict, "user already exists")
			return
		}
		h.logger.Error("register failed", "error", err)
		RespondError(c, http.StatusInternalServerError, "registration failed")
		return
	}
	RespondCreated(c, gin.H{"user": user, "message": "OTP sent to phone"})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req auth.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondValidationError(c, err)
		return
	}
	if strings.TrimSpace(req.Password) == "" {
		RespondError(c, http.StatusBadRequest, "password is required")
		return
	}
	if strings.TrimSpace(req.Phone) == "" && strings.TrimSpace(req.Email) == "" {
		RespondError(c, http.StatusBadRequest, "phone or email is required")
		return
	}

	identifier := strings.TrimSpace(req.Email)
	if identifier == "" {
		identifier = strings.TrimSpace(req.Phone)
	}

	result, err := h.svc.LoginWithEmailOrPhone(c.Request.Context(), req.Phone, req.Email, req.Password)
	if err != nil || result == nil {
		if h.adminH != nil {
			h.adminH.RecordFailedLogin(c.Request.Context(), identifier, c.ClientIP(), c.GetHeader("User-Agent"))
		}
		if errors.Is(err, auth.ErrEmailRequired) {
			RespondError(c, http.StatusForbidden, "staff account must have an email address. Ask the CEO to update your profile.")
			return
		}
		RespondError(c, http.StatusUnauthorized, "invalid credentials")
		return
	}

	// Staff: password OK → require email OTP (no tokens yet)
	if result.Challenge != nil {
		RespondOK(c, result.Challenge)
		return
	}

	resp := result.Auth
	if resp == nil {
		RespondError(c, http.StatusUnauthorized, "invalid credentials")
		return
	}
	if h.adminH != nil && resp.User != nil && auth.IsStaffRole(resp.User.Role) {
		h.adminH.RecordLogin(c.Request.Context(), resp.User.ID, c.ClientIP(), c.GetHeader("User-Agent"))
	}
	if resp.User != nil {
		resp.User.PasswordHash = ""
	}
	RespondOK(c, resp)
}

// VerifyStaffEmailOTP completes staff 2-step login after the email code is entered.
func (h *AuthHandler) VerifyStaffEmailOTP(c *gin.Context) {
	var body struct {
		UserID string `json:"user_id" binding:"required"`
		Code   string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		RespondValidationError(c, err)
		return
	}
	uid, err := uuid.Parse(body.UserID)
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid user_id")
		return
	}
	resp, err := h.svc.VerifyStaffEmailOTP(c.Request.Context(), uid, body.Code)
	if err != nil {
		if errors.Is(err, auth.ErrInvalidOTP) {
			RespondError(c, http.StatusUnauthorized, "invalid or expired code")
			return
		}
		RespondError(c, http.StatusUnauthorized, "invalid credentials")
		return
	}
	if h.adminH != nil && resp.User != nil {
		h.adminH.RecordLogin(c.Request.Context(), resp.User.ID, c.ClientIP(), c.GetHeader("User-Agent"))
	}
	if resp.User != nil {
		resp.User.PasswordHash = ""
	}
	RespondOK(c, resp)
}

func (h *AuthHandler) VerifyOTP(c *gin.Context) {
	var req struct {
		Phone string `json:"phone" binding:"required"`
		Code  string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondValidationError(c, err)
		return
	}
	if err := h.svc.VerifyOTP(c.Request.Context(), req.Phone, req.Code); err != nil {
		RespondError(c, http.StatusBadRequest, "invalid or expired OTP")
		return
	}
	RespondOK(c, gin.H{"message": "phone verified"})
}

func (h *AuthHandler) SendOTP(c *gin.Context) {
	var req struct {
		Phone string `json:"phone" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondValidationError(c, err)
		return
	}
	if err := h.svc.SendOTP(c.Request.Context(), req.Phone); err != nil {
		RespondError(c, http.StatusInternalServerError, "failed to send OTP")
		return
	}
	RespondOK(c, gin.H{"message": "OTP sent"})
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondValidationError(c, err)
		return
	}
	resp, err := h.svc.RefreshToken(c.Request.Context(), req.RefreshToken)
	if err != nil {
		RespondError(c, http.StatusUnauthorized, "invalid refresh token")
		return
	}
	RespondOK(c, resp)
}

func (h *AuthHandler) Profile(c *gin.Context) {
	uid, _ := c.Get("user_id")
	userID, ok := uid.(uuid.UUID)
	if !ok {
		RespondError(c, http.StatusUnauthorized, "invalid session")
		return
	}
	user, err := h.svc.GetProfile(c.Request.Context(), userID)
	if err != nil {
		RespondError(c, http.StatusNotFound, "user not found")
		return
	}
	RespondOK(c, user)
}

func (h *AuthHandler) ChangePassword(c *gin.Context) {
	uid, _ := c.Get("user_id")
	userID := uid.(uuid.UUID)
	var req struct {
		OldPassword string `json:"old_password" binding:"required"`
		NewPassword string `json:"new_password" binding:"required,min=8"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondValidationError(c, err)
		return
	}
	if err := h.svc.ChangePassword(c.Request.Context(), userID, req.OldPassword, req.NewPassword); err != nil {
		RespondError(c, http.StatusBadRequest, "password change failed")
		return
	}
	RespondOK(c, gin.H{"message": "password updated"})
}
