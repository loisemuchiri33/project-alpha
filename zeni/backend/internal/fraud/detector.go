package fraud

import (
	"context"
	"math"
	"sync"
	"time"

	"github.com/zeni-lending/backend/internal/cache"
	"github.com/zeni-lending/backend/pkg/logger"
)

type Detector struct {
	logger *logger.Logger
	cache  *cache.Cache
	mu     sync.RWMutex
	rules  []Rule
}

type Rule struct {
	Name     string
	Weight   float64
	Evaluate func(ctx context.Context, event *Event) float64
}

type Event struct {
	UserID      string
	EventType   string
	Amount      float64
	IPAddress   string
	DeviceID    string
	PhoneNumber string
	Location    string
	HourOfDay   int
	Timestamp   time.Time
}

type RiskScore struct {
	Score      float64            `json:"score"`
	Level      string             `json:"level"`
	RuleScores map[string]float64 `json:"rule_scores"`
	Action     string             `json:"action"`
	Flags      []string           `json:"flags"`
	Confidence float64            `json:"confidence"`
}

func NewDetector(log *logger.Logger, c *cache.Cache) *Detector {
	d := &Detector{logger: log, cache: c}
	d.registerRules()
	return d
}

func (d *Detector) safeIncr(ctx context.Context, key string) int64 {
	if d.cache == nil {
		return 0
	}
	n, _ := d.cache.Increment(ctx, key)
	return n
}

func (d *Detector) safeExpire(ctx context.Context, key string, ttl time.Duration) {
	if d.cache != nil {
		_ = d.cache.Expire(ctx, key, ttl)
	}
}

func (d *Detector) safeGet(ctx context.Context, key string, dest interface{}) {
	if d.cache != nil {
		_ = d.cache.Get(ctx, key, dest)
	}
}

func (d *Detector) safeSet(ctx context.Context, key string, val interface{}, ttl time.Duration) {
	if d.cache != nil {
		_ = d.cache.Set(ctx, key, val, ttl)
	}
}

func (d *Detector) registerRules() {
	d.rules = []Rule{
		{Name: "velocity_check", Weight: 0.25, Evaluate: func(ctx context.Context, e *Event) float64 {
			count := d.safeIncr(ctx, "fraud:velocity:"+e.PhoneNumber)
			d.safeExpire(ctx, "fraud:velocity:"+e.PhoneNumber, 24*time.Hour)
			if count > 10 {
				return 1.0
			}
			if count > 5 {
				return 0.5
			}
			return 0.0
		}},
		{Name: "device_fingerprint", Weight: 0.15, Evaluate: func(ctx context.Context, e *Event) float64 {
			count := d.safeIncr(ctx, "fraud:device_count:"+e.DeviceID)
			if count > 3 {
				return 1.0
			}
			return 0.0
		}},
		{Name: "amount_anomaly", Weight: 0.20, Evaluate: func(ctx context.Context, e *Event) float64 {
			if e.Amount >= 30000 {
				count := d.safeIncr(ctx, "fraud:max_limit:"+e.UserID)
				d.safeExpire(ctx, "fraud:max_limit:"+e.UserID, time.Hour)
				if count > 2 {
					return 0.8
				}
			}
			return 0.0
		}},
		{Name: "time_anomaly", Weight: 0.10, Evaluate: func(ctx context.Context, e *Event) float64 {
			if e.HourOfDay >= 2 && e.HourOfDay <= 5 {
				return 0.3
			}
			return 0.0
		}},
		{Name: "geolocation_anomaly", Weight: 0.10, Evaluate: func(ctx context.Context, e *Event) float64 {
			var last string
			d.safeGet(ctx, "fraud:location:"+e.UserID, &last)
			if last != "" && last != e.Location {
				return 0.6
			}
			d.safeSet(ctx, "fraud:location:"+e.UserID, e.Location, 24*time.Hour)
			return 0.0
		}},
		{Name: "application_spike", Weight: 0.15, Evaluate: func(ctx context.Context, e *Event) float64 {
			count := d.safeIncr(ctx, "fraud:apps:"+e.UserID)
			d.safeExpire(ctx, "fraud:apps:"+e.UserID, 24*time.Hour)
			if count > 5 {
				return 1.0
			}
			if count > 3 {
				return 0.5
			}
			return 0.0
		}},
		{Name: "ip_reputation", Weight: 0.05, Evaluate: func(ctx context.Context, e *Event) float64 {
			return 0.0
		}},
	}
}

func (d *Detector) Assess(ctx context.Context, event *Event) RiskScore {
	d.mu.RLock()
	defer d.mu.RUnlock()
	ruleScores := map[string]float64{}
	var total, weight float64
	var flags []string
	for _, rule := range d.rules {
		s := rule.Evaluate(ctx, event)
		ruleScores[rule.Name] = s
		total += s * rule.Weight
		weight += rule.Weight
		if s > 0.5 {
			flags = append(flags, rule.Name)
		}
	}
	final := 0.0
	if weight > 0 {
		final = math.Round((total/weight)*100) / 100
	}
	level, action := "low", "allow"
	switch {
	case final >= 0.75:
		level, action = "critical", "reject"
	case final >= 0.50:
		level, action = "high", "review"
	case final >= 0.25:
		level, action = "medium", "allow"
	}
	return RiskScore{Score: final, Level: level, RuleScores: ruleScores, Action: action, Flags: flags, Confidence: 0.85}
}
