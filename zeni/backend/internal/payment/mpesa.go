package payment

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/pkg/logger"
)

type MpesaService struct {
	cfg       *config.Config
	logger    *logger.Logger
	client    *http.Client
	authToken string
	tokenExp  time.Time
}

func NewMpesaService(cfg *config.Config, logger *logger.Logger) *MpesaService {
	return &MpesaService{
		cfg:    cfg,
		logger: logger,
		client: &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				MaxIdleConns: 20, IdleConnTimeout: 60 * time.Second,
				DisableCompression: false,
			},
		},
	}
}

func (s *MpesaService) InitiateSTKPush(ctx context.Context, phoneNumber string, amount float64, accountRef string) (*map[string]string, error) {
	phoneNumber = normalizePhone(phoneNumber)
	if len(phoneNumber) != 12 || phoneNumber[:3] != "254" {
		return nil, fmt.Errorf("invalid phone number, must be 254 format")
	}
	if err := s.ensureAuth(ctx); err != nil { return nil, err }

	timestamp := time.Now().Format("20060102150405")
	password := base64.StdEncoding.EncodeToString([]byte(
		s.cfg.Mpesa.ShortCode + s.cfg.Mpesa.Passkey + timestamp))

	reqBody := map[string]interface{}{
		"BusinessShortCode": s.cfg.Mpesa.ShortCode,
		"Password":          password,
		"Timestamp":         timestamp,
		"TransactionType":   "CustomerPayBillOnline",
		"Amount":            int(amount),
		"PartyA":            phoneNumber,
		"PartyB":            s.cfg.Mpesa.ShortCode,
		"PhoneNumber":       phoneNumber,
		"CallBackURL":       s.cfg.Mpesa.CallbackURL,
		"AccountReference":  accountRef,
		"TransactionDesc":   fmt.Sprintf("ZENI Loan - %s", accountRef),
	}
	body, _ := json.Marshal(reqBody)

	req, _ := http.NewRequestWithContext(ctx, "POST", s.cfg.Mpesa.BaseURL+"/mpesa/stkpush/v1/processrequest", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+s.authToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil { return nil, fmt.Errorf("STK push failed: %w", err) }
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	var result map[string]interface{}
	json.Unmarshal(respBody, &result)

	s.logger.Info("STK push initiated", "phone", phoneNumber, "amount", amount)
	res := map[string]string{
		"merchant_request_id": fmt.Sprintf("%v", result["MerchantRequestID"]),
		"checkout_request_id": fmt.Sprintf("%v", result["CheckoutRequestID"]),
	}
	return &res, nil
}

func (s *MpesaService) ensureAuth(ctx context.Context) error {
	if s.authToken != "" && time.Now().Before(s.tokenExp) { return nil }

	authStr := base64.StdEncoding.EncodeToString([]byte(s.cfg.Mpesa.ConsumerKey + ":" + s.cfg.Mpesa.ConsumerSecret))
	req, _ := http.NewRequestWithContext(ctx, "GET", s.cfg.Mpesa.BaseURL+"/oauth/v1/generate?grant_type=client_credentials", nil)
	req.Header.Set("Authorization", "Basic "+authStr)

	resp, err := s.client.Do(req)
	if err != nil { return fmt.Errorf("auth failed: %w", err) }
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var authResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &authResp); err != nil { return fmt.Errorf("auth parse failed: %w", err) }
	if authResp.AccessToken == "" { return fmt.Errorf("M-Pesa auth failed") }

	s.authToken = authResp.AccessToken
	s.tokenExp = time.Now().Add(time.Duration(authResp.ExpiresIn-60) * time.Second)
	s.logger.Info("M-Pesa auth token obtained")
	return nil
}

func (s *MpesaService) DisburseFunds(ctx context.Context, phoneNumber string, amount float64, remarks string) error {
	phoneNumber = normalizePhone(phoneNumber)
	if len(phoneNumber) != 12 || phoneNumber[:3] != "254" {
		return fmt.Errorf("invalid phone number, must be 254 format")
	}
	if amount < 10 {
		return fmt.Errorf("disbursement amount too small")
	}
	if err := s.ensureAuth(ctx); err != nil {
		return err
	}

	certPEM := []byte(s.cfg.Mpesa.Certificate)
	if len(certPEM) == 0 {
		return fmt.Errorf("M-Pesa initiator certificate not configured")
	}
	block, _ := pem.Decode(certPEM)
	if block == nil {
		return fmt.Errorf("invalid M-Pesa certificate PEM")
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return fmt.Errorf("parse M-Pesa certificate: %w", err)
	}
	pub, ok := cert.PublicKey.(*rsa.PublicKey)
	if !ok {
		return fmt.Errorf("M-Pesa certificate is not RSA")
	}
	encryptedBytes, err := rsa.EncryptOAEP(sha256.New(), rand.Reader, pub, []byte(s.cfg.Mpesa.Passkey), nil)
	if err != nil {
		return fmt.Errorf("encrypt security credential: %w", err)
	}
	securityCredential := base64.StdEncoding.EncodeToString(encryptedBytes)

	reqBody := map[string]interface{}{
		"InitiatorName":      s.cfg.Mpesa.InitiatorName,
		"SecurityCredential": securityCredential,
		"CommandID":          "BusinessPayment",
		"Amount":             int(amount),
		"PartyA":             s.cfg.Mpesa.ShortCode,
		"PartyB":             phoneNumber,
		"Remarks":            remarks,
		"QueueTimeOutURL":    s.cfg.Mpesa.TimeoutURL,
		"ResultURL":          s.cfg.Mpesa.ResultURL,
		"Occasion":           "ZENI Loan Disbursement",
	}
	body, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("marshal B2C request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", s.cfg.Mpesa.BaseURL+"/mpesa/b2c/v1/paymentrequest", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+s.authToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return fmt.Errorf("B2C request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		s.logger.Error("B2C rejected by Safaricom", "status", resp.StatusCode, "body", string(respBody))
		return fmt.Errorf("B2C rejected by Safaricom (HTTP %d)", resp.StatusCode)
	}

	var result map[string]interface{}
	_ = json.Unmarshal(respBody, &result)
	if code, ok := result["ResponseCode"].(string); ok && code != "0" {
		desc, _ := result["ResponseDescription"].(string)
		return fmt.Errorf("B2C error %s: %s", code, desc)
	}

	s.logger.Info("B2C payment initiated", "phone", phoneNumber, "amount", amount, "conversation_id", result["ConversationID"])
	return nil
}

func normalizePhone(phone string) string {
	cleaned := ""
	for _, c := range phone { if c >= '0' && c <= '9' { cleaned += string(c) } }
	if len(cleaned) == 10 && cleaned[0] == '0' { cleaned = "254" + cleaned[1:] }
	if len(cleaned) == 9 { cleaned = "254" + cleaned }
	return cleaned
}
