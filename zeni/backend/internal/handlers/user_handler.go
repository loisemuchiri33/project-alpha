package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/auth"
	"github.com/zeni-lending/backend/pkg/logger"
)

type UserHandler struct {
	auth   *auth.Service
	logger *logger.Logger
}

func NewUserHandler(authSvc *auth.Service, log *logger.Logger) *UserHandler {
	return &UserHandler{auth: authSvc, logger: log}
}

func (h *UserHandler) GetProfile(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	user, err := h.auth.GetProfile(c.Request.Context(), userID)
	if err != nil {
		RespondError(c, http.StatusNotFound, "user not found")
		return
	}
	RespondOK(c, user)
}
