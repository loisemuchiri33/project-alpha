package email

import (
	"fmt"
	"net/smtp"
	"strings"

	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/pkg/logger"
)

type Service struct {
	cfg    config.EmailConfig
	logger *logger.Logger
}

func NewService(cfg config.EmailConfig, log *logger.Logger) *Service {
	return &Service{cfg: cfg, logger: log}
}

// Send delivers a plain-text email. When SMTP is not configured, the message is logged (dev mode).
func (s *Service) Send(to, subject, body string) error {
	to = strings.TrimSpace(strings.ToLower(to))
	if to == "" || !strings.Contains(to, "@") {
		return fmt.Errorf("invalid email address")
	}
	if s.cfg.Host == "" || s.cfg.User == "" {
		s.logger.Info("EMAIL (dev — SMTP not configured)", "to", maskEmail(to), "subject", subject, "body", body)
		return nil
	}

	from := s.cfg.From
	if from == "" {
		from = s.cfg.User
	}
	addr := fmt.Sprintf("%s:%d", s.cfg.Host, s.cfg.Port)
	if s.cfg.Port == 0 {
		addr = fmt.Sprintf("%s:587", s.cfg.Host)
	}

	msg := strings.Join([]string{
		"From: " + from,
		"To: " + to,
		"Subject: " + subject,
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"",
		body,
	}, "\r\n")

	auth := smtp.PlainAuth("", s.cfg.User, s.cfg.Password, s.cfg.Host)
	if err := smtp.SendMail(addr, auth, from, []string{to}, []byte(msg)); err != nil {
		s.logger.Error("email send failed", "to", maskEmail(to), "error", err)
		return fmt.Errorf("failed to send email: %w", err)
	}
	s.logger.Info("email sent", "to", maskEmail(to), "subject", subject)
	return nil
}

func maskEmail(e string) string {
	parts := strings.SplitN(e, "@", 2)
	if len(parts) != 2 {
		return "***"
	}
	local := parts[0]
	if len(local) <= 2 {
		return "***@" + parts[1]
	}
	return local[:2] + "***@" + parts[1]
}
