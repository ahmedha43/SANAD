package repository

import (
	"fmt"
	"log"
	"time"

	"github.com/parental-control/backend/config"
	"github.com/parental-control/backend/internal/domain"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func NewPostgresDB(cfg *config.Config) (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s TimeZone=UTC",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName, cfg.DBSSLMode,
	)

	var db *gorm.DB
	var err error

	for attempts := 1; attempts <= 10; attempts++ {
		db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Warn),
		})
		if err == nil {
			break
		}
		log.Printf("Waiting for PostgreSQL (attempt %d/10): %v", attempts, err)
		time.Sleep(2 * time.Second)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to connect to PostgreSQL after retries: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}

	// Connection pooling
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(50)
	sqlDB.SetConnMaxLifetime(time.Hour)

	log.Println("Connected to PostgreSQL successfully")

	// Auto-migrate tables if needed
	err = db.AutoMigrate(
		&domain.User{},
		&domain.Family{},
		&domain.Subscription{},
		&domain.Child{},
		&domain.Device{},
		&domain.PairingCode{},
		&domain.LocationLog{},
		&domain.Geofence{},
		&domain.GeofenceEvent{},
		&domain.DeviceApp{},
		&domain.AppUsageDaily{},
		&domain.ScreenTimeRule{},
		&domain.DeviceCommand{},
		&domain.KidNotification{},
		&domain.KidContact{},
		&domain.KidSMS{},
		&domain.KidFile{},
		&domain.AuditLog{},
		&domain.SubscriptionPlan{},
	)
	if err != nil {
		log.Printf("GORM AutoMigrate notice: %v", err)
	}

	seedDefaultPlans(db)

	return db, nil
}

func seedDefaultPlans(db *gorm.DB) {
	var count int64
	db.Model(&domain.SubscriptionPlan{}).Count(&count)
	if count > 0 {
		return
	}

	defaultPlans := []domain.SubscriptionPlan{
		{
			ID:           "plan_free",
			Name:         "الباقة التجريبية المجانية",
			Tier:         "free",
			Price:        0,
			Currency:     "USD",
			BillingCycle: "lifetime",
			DurationDays: 0,
			MaxDevices:   1,
			Features:     `["live_gps", "calls_log", "sms_log"]`,
			IsActive:     true,
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		},
		{
			ID:           "plan_basic_monthly",
			Name:         "الباقة الأساسية الشهرية",
			Tier:         "basic",
			Price:        9.99,
			Currency:     "USD",
			BillingCycle: "monthly",
			DurationDays: 30,
			MaxDevices:   3,
			Features:     `["live_gps", "geofencing", "app_blocking", "screen_time", "calls_log", "sms_log", "contacts"]`,
			IsActive:     true,
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		},
		{
			ID:           "plan_premium_yearly",
			Name:         "الباقة المتقدمة السنوية",
			Tier:         "premium",
			Price:        79.99,
			Currency:     "USD",
			BillingCycle: "yearly",
			DurationDays: 365,
			MaxDevices:   5,
			Features:     `["live_gps", "route_replay", "geofencing", "app_blocking", "screen_time", "silent_screenshot", "ai_risk_detection", "media_gallery", "notifications", "anti_uninstall", "stealth_mode", "settings_protection"]`,
			IsActive:     true,
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		},
		{
			ID:           "plan_family_unlimited",
			Name:         "باقة العائلة غير المحدودة VIP",
			Tier:         "family_unlimited",
			Price:        149.99,
			Currency:     "USD",
			BillingCycle: "yearly",
			DurationDays: 365,
			MaxDevices:   99,
			Features:     `["live_gps", "route_replay", "geofencing", "app_blocking", "screen_time", "silent_screenshot", "live_camera", "webrtc_stream", "ai_risk_detection", "media_gallery", "notifications", "zero_knowledge_e2ee", "priority_support", "anti_uninstall", "stealth_mode", "settings_protection"]`,
			IsActive:     true,
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		},
	}

	for _, p := range defaultPlans {
		db.FirstOrCreate(&p, domain.SubscriptionPlan{ID: p.ID})
	}
	log.Printf("Seeded %d default subscription plans", len(defaultPlans))
}
