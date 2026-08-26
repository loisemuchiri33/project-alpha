package sms

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/pkg/logger"
)

// Service sends SMS via the configured provider (Africa's Talking by default).
type Service struct {
	cfg    config.SMSConfig
	client *http.Client
	logger *logger.Logger
}

func NewService(cfg config.SMSConfig, log *logger.Logger) *Service {
	return &Service{
		cfg: cfg,
		client: &http.Client{
			Timeout: 15 * time.Second,
		},
		logger: log,
	}
}

// Send delivers a plain-text SMS to a single Kenyan phone number (254...).
// Returns nil on success. When API key is empty the message is logged only (dev mode).
func (s *Service) Send(ctx context.Context, phone, message string) error {
	phone = normalizePhone(phone)
	if phone == "" {
		return fmt.Errorf("invalid phone number")
	}
	if strings.TrimSpace(message) == "" {
		return fmt.Errorf("empty message")
	}

	if s.cfg.APIKey == "" {
		s.logger.Info("SMS skipped (no API key) — would send", "phone", mask(phone), "len", len(message))
		return nil
	}

	switch strings.ToLower(s.cfg.Provider) {
	case "africastalking", "at", "":
		return s.sendAfricasTalking(ctx, phone, message)
	default:
		return fmt.Errorf("unsupported SMS provider: %s", s.cfg.Provider)
	}
}

func (s *Service) sendAfricasTalking(ctx context.Context, phone, message string) error {
	username := s.cfg.Username
	if username == "" {
		username = "sandbox"
	}

	form := url.Values{}
	form.Set("username", username)
	form.Set("to", phone)
	form.Set("message", message)
	if s.cfg.SenderID != "" {
		form.Set("from", s.cfg.SenderID)
	}

	endpoint := strings.TrimRight(s.cfg.BaseURL, "/") + "/version1/messaging"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("apiKey", s.cfg.APIKey)

	resp, err := s.client.Do(req)
	if err != nil {
		return fmt.Errorf("SMS request failed: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		s.logger.Error("SMS provider error", "status", resp.StatusCode, "body", string(body))
		return fmt.Errorf("SMS provider returned %d", resp.StatusCode)
	}

	var parsed map[string]interface{}
	_ = json.Unmarshal(body, &parsed)
	s.logger.Info("SMS sent", "phone", mask(phone), "provider", "africastalking")
	return nil
}

func normalizePhone(phone string) string {
	var b strings.Builder
	for _, ch := range phone {
		if ch >= '0' && ch <= '9' {
			b.WriteRune(ch)
		}
	}
	cleaned := b.String()
	if len(cleaned) == 10 && cleaned[0] == '0' {
		cleaned = "254" + cleaned[1:]
	}
	if len(cleaned) == 9 {
		cleaned = "254" + cleaned
	}
	if len(cleaned) != 12 || !strings.HasPrefix(cleaned, "254") {
		return ""
	}
	return cleaned
}

func mask(phone string) string {
	if len(phone) < 6 {
		return "***"
	}
	return phone[:4] + "****" + phone[len(phone)-2:]
}

// PaymentReminderMessage builds a concise repayment reminder.
func PaymentReminderMessage(borrowerName string, amountDue float64, dueDate *time.Time, custom string) string {
	if custom != "" {
		return custom
	}
	name := strings.TrimSpace(borrowerName)
	if name == "" {
		name = "Customer"
	}
	msg := fmt.Sprintf("Dear %s, your ZENI loan balance of KES %.0f is due", name, amountDue)
	if dueDate != nil {
		msg += fmt.Sprintf(" on %s", dueDate.Format("02 Jan 2006"))
	}
	msg += ". Please repay via M-Pesa to avoid late fees. - ZENI"
	return msg
}
