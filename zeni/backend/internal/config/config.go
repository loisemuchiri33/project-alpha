package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	Mpesa    MpesaConfig
	SMS      SMSConfig
	Email    EmailConfig
	Storage  StorageConfig
}

type ServerConfig struct {
	Port         string
	Mode         string
	Timeout      int
	ReadTimeout  int
	WriteTimeout int
}

type DatabaseConfig struct {
	Host           string
	Port           string
	User           string
	Password       string
	Name           string
	SSLMode        string
	MaxOpenConns   int
	MaxIdleConns   int
	ConnMaxLifetime time.Duration
	MigrationsPath string
}

type RedisConfig struct {
	Host         string
	Port         string
	Password     string
	DB           int
	PoolSize     int
	MinIdleConns int
}

type JWTConfig struct {
	Secret     string
	AccessTTL  int
	RefreshTTL int
	Issuer     string
}

type MpesaConfig struct {
	ConsumerKey     string
	ConsumerSecret  string
	Passkey         string
	ShortCode       string
	InitiatorName   string
	Certificate     string
	BaseURL         string
	CallbackURL     string
	TimeoutURL      string
	ResultURL       string
	CallbackSecret  string // shared secret required on callback header
}

type SMSConfig struct {
	Username string
	Provider string
	APIKey   string
	SenderID string
	BaseURL  string
}

type EmailConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	From     string
}

type StorageConfig struct {
	Endpoint  string
	AccessKey string
	SecretKey string
	Bucket    string
	UseSSL    bool
}

var knownWeakJWT = map[string]struct{}{
	"": {},
	"zeni-jwt-secret-change-in-production":                        {},
	"change-me-to-a-long-random-secret-at-least-32-chars":        {},
	"change-me-to-a-long-random-secret-at-least-32-chars-please": {},
}

func Load() *Config {
	return &Config{
		Server: ServerConfig{
			Port:         getEnv("SERVER_PORT", "8080"),
			Mode:         getEnv("GIN_MODE", "release"),
			Timeout:      getEnvInt("SERVER_TIMEOUT", 30),
			ReadTimeout:  getEnvInt("SERVER_READ_TIMEOUT", 10),
			WriteTimeout: getEnvInt("SERVER_WRITE_TIMEOUT", 30),
		},
		Database: DatabaseConfig{
			Host:           getEnv("DB_HOST", "localhost"),
			Port:           getEnv("DB_PORT", "5432"),
			User:           getEnv("DB_USER", "zeni"),
			Password:       getEnv("DB_PASSWORD", ""),
			Name:           getEnv("DB_NAME", "zeni"),
			SSLMode:        getEnv("DB_SSLMODE", "disable"),
			MaxOpenConns:   getEnvInt("DB_MAX_OPEN_CONNS", 25),
			MaxIdleConns:   getEnvInt("DB_MAX_IDLE_CONNS", 5),
			ConnMaxLifetime: time.Duration(getEnvInt("DB_CONN_MAX_LIFETIME", 30)) * time.Minute,
			MigrationsPath: getEnv("DB_MIGRATIONS_PATH", "migrations"),
		},
		Redis: RedisConfig{
			Host:         getEnv("REDIS_HOST", "localhost"),
			Port:         getEnv("REDIS_PORT", "6379"),
			Password:     getEnv("REDIS_PASSWORD", ""),
			DB:           getEnvInt("REDIS_DB", 0),
			PoolSize:     getEnvInt("REDIS_POOL_SIZE", 20),
			MinIdleConns: getEnvInt("REDIS_MIN_IDLE", 5),
		},
		JWT: JWTConfig{
			Secret:     getEnv("JWT_SECRET", ""),
			AccessTTL:  getEnvInt("JWT_ACCESS_TTL", 900),
			RefreshTTL: getEnvInt("JWT_REFRESH_TTL", 1209600),
			Issuer:     getEnv("JWT_ISSUER", "zeni-lending"),
		},
		Mpesa: MpesaConfig{
			ConsumerKey:    getEnv("MPESA_CONSUMER_KEY", ""),
			ConsumerSecret: getEnv("MPESA_CONSUMER_SECRET", ""),
			Passkey:        getEnv("MPESA_PASSKEY", ""),
			ShortCode:      getEnv("MPESA_SHORTCODE", "174379"),
			InitiatorName:  getEnv("MPESA_INITIATOR_NAME", "testapi"),
			Certificate:    getEnv("MPESA_CERTIFICATE", ""),
			BaseURL:        getEnv("MPESA_BASE_URL", "https://sandbox.safaricom.co.ke"),
			CallbackURL:    getEnv("MPESA_CALLBACK_URL", "https://api.zeni.co.ke/api/v1/payments/callback"),
			TimeoutURL:     getEnv("MPESA_TIMEOUT_URL", "https://api.zeni.co.ke/api/v1/payments/timeout"),
			ResultURL:      getEnv("MPESA_RESULT_URL", "https://api.zeni.co.ke/api/v1/payments/result"),
			CallbackSecret: getEnv("MPESA_CALLBACK_SECRET", ""),
		},
		SMS: SMSConfig{
			Username: getEnv("SMS_USERNAME", ""),
			Provider: getEnv("SMS_PROVIDER", "africastalking"),
			APIKey:   getEnv("SMS_API_KEY", ""),
			SenderID: getEnv("SMS_SENDER_ID", "ZENI"),
			BaseURL:  getEnv("SMS_BASE_URL", "https://api.africastalking.com"),
		},
		Email: EmailConfig{
			Host:     getEnv("SMTP_HOST", ""),
			Port:     getEnvInt("SMTP_PORT", 587),
			User:     getEnv("SMTP_USER", ""),
			Password: getEnv("SMTP_PASSWORD", ""),
			From:     getEnv("SMTP_FROM", ""),
		},
		Storage: StorageConfig{
			Endpoint:  getEnv("STORAGE_ENDPOINT", "localhost:9000"),
			AccessKey: getEnv("STORAGE_ACCESS_KEY", ""),
			SecretKey: getEnv("STORAGE_SECRET_KEY", ""),
			Bucket:    getEnv("STORAGE_BUCKET", "zeni-documents"),
			UseSSL:    getEnvBool("STORAGE_USE_SSL", false),
		},
	}
}

// ValidateJWT returns error if JWT secret is missing/weak in release mode.
// In non-release, supplies a deterministic local-only secret for scaffold demos.
func (c *Config) ValidateJWT() error {
	_, weakKnown := knownWeakJWT[c.JWT.Secret]
	weak := weakKnown || len(c.JWT.Secret) < 32
	if c.Server.Mode == "release" {
		if weak {
			return fmt.Errorf("JWT_SECRET must be set to a random value of at least 32 characters (not a documented default)")
		}
		return nil
	}
	if weak {
		// Local/dev scaffold only — never rely on this in production.
		c.JWT.Secret = "zeni-local-dev-only-secret-do-not-use-in-prod!!"
	}
	return nil
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return strings.TrimSpace(val)
	}
	return defaultVal
}

func getEnvInt(key string, defaultVal int) int {
	if val := os.Getenv(key); val != "" {
		if i, err := strconv.Atoi(strings.TrimSpace(val)); err == nil {
			return i
		}
	}
	return defaultVal
}

func getEnvBool(key string, defaultVal bool) bool {
	if val := os.Getenv(key); val != "" {
		switch strings.ToLower(strings.TrimSpace(val)) {
		case "true", "1", "yes":
			return true
		case "false", "0", "no":
			return false
		}
	}
	return defaultVal
}
