CREATE TABLE IF NOT EXISTS subscription_plans (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    tier VARCHAR(50) NOT NULL,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    billing_cycle VARCHAR(20) NOT NULL DEFAULT 'monthly',
    duration_days INT NOT NULL DEFAULT 30,
    max_devices INT NOT NULL DEFAULT 2,
    features TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO subscription_plans (id, name, tier, price, currency, billing_cycle, duration_days, max_devices, features, is_active)
VALUES 
('plan_free', 'الباقة التجريبية المجانية', 'free', 0.00, 'USD', 'lifetime', 0, 1, '["live_gps", "calls_log", "sms_log"]', true),
('plan_basic_monthly', 'الباقة الأساسية الشهرية', 'basic', 9.99, 'USD', 'monthly', 30, 3, '["live_gps", "geofencing", "app_blocking", "screen_time", "calls_log", "sms_log", "contacts"]', true),
('plan_premium_yearly', 'الباقة المتقدمة السنوية', 'premium', 79.99, 'USD', 'yearly', 365, 5, '["live_gps", "route_replay", "geofencing", "app_blocking", "screen_time", "silent_screenshot", "ai_risk_detection", "media_gallery", "notifications"]', true),
('plan_family_unlimited', 'باقة العائلة غير المحدودة VIP', 'family_unlimited', 149.99, 'USD', 'yearly', 365, 99, '["live_gps", "route_replay", "geofencing", "app_blocking", "screen_time", "silent_screenshot", "live_camera", "webrtc_stream", "ai_risk_detection", "media_gallery", "notifications", "zero_knowledge_e2ee", "priority_support"]', true)
ON CONFLICT (id) DO NOTHING;
