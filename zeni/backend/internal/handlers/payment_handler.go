package handlers

import (
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/internal/database/repositories"
	"github.com/zeni-lending/backend/internal/loan"
	"github.com/zeni-lending/backend/internal/payment"
	"github.com/zeni-lending/backend/pkg/logger"
)

type PaymentHandler struct {
	mpesa       *payment.MpesaService
	repo        loan.LoanRepository
	engine      *loan.Engine
	intents     *repositories.PaymentIntentRepo
	cfg         *config.Config
	logger      *logger.Logger
}

func NewPaymentHandler(mpesa *payment.MpesaService, repo loan.LoanRepository, cfg *config.Config, log *logger.Logger) *PaymentHandler {
	return &PaymentHandler{mpesa: mpesa, repo: repo, cfg: cfg, logger: log}
}

func (h *PaymentHandler) SetEngine(e *loan.Engine) { h.engine = e }
func (h *PaymentHandler) SetIntentRepo(r *repositories.PaymentIntentRepo) { h.intents = r }

func (h *PaymentHandler) STKPush(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	var req struct {
		Phone  string  `json:"phone" binding:"required"`
		Amount float64 `json:"amount" binding:"required,gt=0"`
		LoanID string  `json:"loan_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondValidationError(c, err)
		return
	}
	loanID, err := uuid.Parse(req.LoanID)
	if err != nil {
		RespondError(c, http.StatusBadRequest, "invalid loan_id")
		return
	}
	if h.repo == nil {
		RespondError(c, http.StatusServiceUnavailable, "database offline")
		return
	}
	l, err := h.repo.FindByID(c.Request.Context(), loanID)
	if err != nil || l == nil {
		RespondError(c, http.StatusNotFound, "loan not found")
		return
	}
	if l.UserID != userID {
		RespondError(c, http.StatusForbidden, "loan does not belong to caller")
		return
	}
	if l.Status != "active" {
		RespondError(c, http.StatusBadRequest, "loan is not active for repayment")
		return
	}
	outstanding := l.TotalRepayment - l.AmountPaid
	if outstanding <= 0 {
		RespondError(c, http.StatusBadRequest, "loan is already fully paid")
		return
	}
	if req.Amount > outstanding+1 {
		RespondError(c, http.StatusBadRequest, "amount exceeds outstanding balance")
		return
	}

	// Create payment intent before STK so callback can bind CheckoutRequestID → ledger.
	var intentID uuid.UUID
	if h.intents != nil {
		intent := &repositories.PaymentIntent{
			UserID: userID, LoanID: loanID, Amount: req.Amount, PhoneNumber: req.Phone, Status: "pending",
		}
		if err := h.intents.Create(c.Request.Context(), intent); err != nil {
			h.logger.Error("payment intent create failed", "error", err)
			RespondError(c, http.StatusInternalServerError, "failed to create payment intent")
			return
		}
		intentID = intent.ID
	}

	ref := "ZNI-" + loanID.String()[:8]
	result, err := h.mpesa.InitiateSTKPush(c.Request.Context(), req.Phone, req.Amount, ref)
	if err != nil {
		h.logger.Error("stk push failed", "error", err, "user", userID, "loan", loanID)
		if h.intents != nil && intentID != uuid.Nil {
			_ = h.intents.Fail(c.Request.Context(), intentID)
		}
		RespondError(c, http.StatusBadGateway, "payment initiation failed")
		return
	}
	if h.intents != nil && intentID != uuid.Nil && result != nil {
		checkout := (*result)["checkout_request_id"]
		merchant := (*result)["merchant_request_id"]
		if checkout != "" && checkout != "<nil>" {
			if err := h.intents.BindCheckoutIDs(c.Request.Context(), intentID, checkout, merchant); err != nil {
				h.logger.Error("bind checkout id failed", "error", err, "intent", intentID)
			}
		}
	}
	out := gin.H{}
	if result != nil {
		for k, v := range *result {
			out[k] = v
		}
	}
	if intentID != uuid.Nil {
		out["payment_intent_id"] = intentID
	}
	RespondOK(c, out)
}

// stkCallbackBody is the Safaricom STK callback envelope.
type stkCallbackBody struct {
	Body struct {
		StkCallback struct {
			MerchantRequestID string `json:"MerchantRequestID"`
			CheckoutRequestID string `json:"CheckoutRequestID"`
			ResultCode        int    `json:"ResultCode"`
			ResultDesc        string `json:"ResultDesc"`
			CallbackMetadata  *struct {
				Item []struct {
					Name  string      `json:"Name"`
					Value interface{} `json:"Value"`
				} `json:"Item"`
			} `json:"CallbackMetadata"`
		} `json:"stkCallback"`
	} `json:"Body"`
}

func (h *PaymentHandler) Callback(c *gin.Context) {
	secret := ""
	if h.cfg != nil {
		secret = h.cfg.Mpesa.CallbackSecret
	}
	if secret != "" {
		// Header-only — never accept secret via query string (logs / Referer leaks).
		provided := c.GetHeader("X-Callback-Secret")
		if subtle.ConstantTimeCompare([]byte(provided), []byte(secret)) != 1 {
			h.logger.Warn("mpesa callback rejected: bad secret", "ip", c.ClientIP())
			c.JSON(http.StatusUnauthorized, gin.H{"ResultCode": 1, "ResultDesc": "Rejected"})
			return
		}
	} else if h.cfg != nil && h.cfg.Server.Mode == "release" {
		h.logger.Error("mpesa callback rejected: MPESA_CALLBACK_SECRET not configured")
		c.JSON(http.StatusUnauthorized, gin.H{"ResultCode": 1, "ResultDesc": "Rejected"})
		return
	}

	raw, err := c.GetRawData()
	if err != nil || len(raw) == 0 {
		RespondError(c, http.StatusBadRequest, "invalid callback")
		return
	}

	var envelope map[string]interface{}
	if err := json.Unmarshal(raw, &envelope); err != nil {
		RespondError(c, http.StatusBadRequest, "invalid callback")
		return
	}
	if _, ok := envelope["Body"]; !ok {
		if _, ok2 := envelope["Result"]; !ok2 {
			h.logger.Warn("mpesa callback rejected: unexpected payload", "ip", c.ClientIP())
			c.JSON(http.StatusBadRequest, gin.H{"ResultCode": 1, "ResultDesc": "Invalid payload"})
			return
		}
		// B2C Result path — acknowledge only (disbursement result wiring is separate).
		h.logger.Info("mpesa result callback accepted", "ip", c.ClientIP())
		c.JSON(http.StatusOK, gin.H{"ResultCode": 0, "ResultDesc": "Accepted"})
		return
	}

	var stk stkCallbackBody
	if err := json.Unmarshal(raw, &stk); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"ResultCode": 1, "ResultDesc": "Invalid payload"})
		return
	}
	cb := stk.Body.StkCallback
	if cb.CheckoutRequestID == "" {
		h.logger.Warn("mpesa callback missing CheckoutRequestID", "ip", c.ClientIP())
		c.JSON(http.StatusBadRequest, gin.H{"ResultCode": 1, "ResultDesc": "Missing CheckoutRequestID"})
		return
	}

	if h.intents == nil || h.engine == nil {
		h.logger.Warn("payment callback: intent/engine not wired — accept without ledger")
		c.JSON(http.StatusOK, gin.H{"ResultCode": 0, "ResultDesc": "Accepted"})
		return
	}

	intent, err := h.intents.FindByCheckoutRequestID(c.Request.Context(), cb.CheckoutRequestID)
	if err != nil || intent == nil {
		h.logger.Warn("mpesa callback unbound checkout id", "checkout", cb.CheckoutRequestID, "ip", c.ClientIP())
		// Still 200 so Daraja does not infinite-retry; do not post ledger.
		c.JSON(http.StatusOK, gin.H{"ResultCode": 0, "ResultDesc": "Accepted"})
		return
	}

	if cb.ResultCode != 0 {
		_ = h.intents.Fail(c.Request.Context(), intent.ID)
		h.logger.Info("stk payment failed", "intent", intent.ID, "code", cb.ResultCode, "desc", cb.ResultDesc)
		c.JSON(http.StatusOK, gin.H{"ResultCode": 0, "ResultDesc": "Accepted"})
		return
	}

	amount, receipt := extractSTKMeta(cb.CallbackMetadata)
	if amount <= 0 {
		amount = intent.Amount
	}
	// Cap to intent amount to prevent over-credit from forged metadata (secret still required).
	if amount > intent.Amount+1 {
		amount = intent.Amount
	}

	ok, err := h.intents.CompleteIfPending(c.Request.Context(), intent.ID, receipt)
	if err != nil {
		h.logger.Error("intent complete failed", "error", err)
		c.JSON(http.StatusOK, gin.H{"ResultCode": 0, "ResultDesc": "Accepted"})
		return
	}
	if !ok {
		// Already processed — idempotent.
		c.JSON(http.StatusOK, gin.H{"ResultCode": 0, "ResultDesc": "Accepted"})
		return
	}

	ref := receipt
	if ref == "" {
		ref = fmt.Sprintf("STK-%s", cb.CheckoutRequestID)
	}
	_, err = h.engine.RecordPayment(c.Request.Context(), &struct {
		LoanID         uuid.UUID
		Amount         float64
		PaymentMethod  string
		TransactionRef string
		PaidAt         time.Time
	}{
		LoanID: intent.LoanID, Amount: amount, PaymentMethod: "mpesa_stk",
		TransactionRef: ref, PaidAt: time.Now(),
	})
	if err != nil {
		h.logger.Error("ledger post failed after stk success", "error", err, "loan", intent.LoanID, "intent", intent.ID)
		// Intent already completed — ops must reconcile; avoid double-pay on retry.
	} else {
		h.logger.Info("repayment posted", "loan", intent.LoanID, "amount", amount, "receipt", receipt)
	}
	c.JSON(http.StatusOK, gin.H{"ResultCode": 0, "ResultDesc": "Accepted"})
}

func extractSTKMeta(meta *struct {
	Item []struct {
		Name  string      `json:"Name"`
		Value interface{} `json:"Value"`
	} `json:"Item"`
}) (amount float64, receipt string) {
	if meta == nil {
		return 0, ""
	}
	for _, it := range meta.Item {
		switch it.Name {
		case "Amount":
			switch v := it.Value.(type) {
			case float64:
				amount = v
			case int:
				amount = float64(v)
			case json.Number:
				f, _ := v.Float64()
				amount = f
			case string:
				fmt.Sscanf(v, "%f", &amount)
			}
		case "MpesaReceiptNumber":
			receipt = fmt.Sprintf("%v", it.Value)
		}
	}
	return amount, receipt
}
