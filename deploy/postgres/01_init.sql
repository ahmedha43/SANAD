-- Parental Control Platform Initial Database Schema
-- Compatibility: PostgreSQL 14+

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('superadmin', 'admin', 'parent');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE device_status AS ENUM ('online', 'offline', 'sleep');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE command_status AS ENUM ('pending', 'sent', 'delivered', 'executed', 'failed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE subscription_tier AS ENUM ('free', 'basic', 'premium', 'family_unlimited');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 1. Users (Parents & Admins)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(30),
    role user_role NOT NULL DEFAULT 'parent',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Families (Tenancy Partitioning)
CREATE TABLE IF NOT EXISTS families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Subscriptions & Licensing
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    tier subscription_tier NOT NULL DEFAULT 'free',
    max_devices INT NOT NULL DEFAULT 2,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    payment_reference VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Children Profiles
CREATE TABLE IF NOT EXISTS children (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    birth_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Devices (Kids Agents)
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID REFERENCES children(id) ON DELETE SET NULL,
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    device_uid VARCHAR(100) UNIQUE NOT NULL,
    device_name VARCHAR(100) NOT NULL,
    model VARCHAR(100),
    os_version VARCHAR(50),
    os_type VARCHAR(20) DEFAULT 'android',
    app_version VARCHAR(50),
    battery_level INT DEFAULT 100,
    is_charging BOOLEAN DEFAULT FALSE,
    network_type VARCHAR(30),
    status device_status NOT NULL DEFAULT 'offline',
    pairing_secret VARCHAR(64) NOT NULL,
    fcm_token TEXT,
    last_seen_at TIMESTAMPTZ,
    is_monitoring_paused BOOLEAN NOT NULL DEFAULT FALSE,
    is_web_filter_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_devices_family_id ON devices(family_id);
CREATE INDEX IF NOT EXISTS idx_devices_uid ON devices(device_uid);

-- 6. Pairing Codes (Temporary 6-digit codes)
CREATE TABLE IF NOT EXISTS pairing_codes (
    code VARCHAR(6) PRIMARY KEY,
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    child_id UUID REFERENCES children(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_pairing_codes_expires ON pairing_codes(expires_at);

-- 7. Location History & Tracking
CREATE TABLE IF NOT EXISTS location_logs (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy REAL,
    altitude REAL,
    speed REAL,
    bearing REAL,
    recorded_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_location_logs_device_time ON location_logs(device_id, recorded_at DESC);

-- 8. Geofences
CREATE TABLE IF NOT EXISTS geofences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters INT NOT NULL DEFAULT 200,
    alert_on_entry BOOLEAN NOT NULL DEFAULT TRUE,
    alert_on_exit BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Geofence Trigger Events
CREATE TABLE IF NOT EXISTS geofence_events (
    id BIGSERIAL PRIMARY KEY,
    geofence_id UUID NOT NULL REFERENCES geofences(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    event_type VARCHAR(20) NOT NULL, -- 'ENTER' or 'EXIT'
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. Installed Apps
CREATE TABLE IF NOT EXISTS device_apps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    package_name VARCHAR(255) NOT NULL,
    app_name VARCHAR(255) NOT NULL,
    icon_url TEXT,
    is_system_app BOOLEAN DEFAULT FALSE,
    is_blocked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(device_id, package_name)
);

-- 11. Daily App Usage Stats
CREATE TABLE IF NOT EXISTS app_usage_daily (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    package_name VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    usage_duration_seconds INT NOT NULL DEFAULT 0,
    open_count INT NOT NULL DEFAULT 0,
    last_used_at TIMESTAMPTZ,
    UNIQUE(device_id, package_name, date)
);

CREATE INDEX IF NOT EXISTS idx_app_usage_device_date ON app_usage_daily(device_id, date);

-- 12. Screen Time Rules & Limits
CREATE TABLE IF NOT EXISTS screen_time_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    daily_limit_minutes INT DEFAULT 180,
    downtime_start TIME,
    downtime_end TIME,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(device_id)
);

-- 13. Commands Queue
CREATE TABLE IF NOT EXISTS device_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    command_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    status command_status NOT NULL DEFAULT 'pending',
    error_message TEXT,
    executed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_commands_device_status ON device_commands(device_id, status);

-- 14. Notifications Log (Synced from Kid)
CREATE TABLE IF NOT EXISTS kid_notifications (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    app_name VARCHAR(100) NOT NULL,
    package_name VARCHAR(255) NOT NULL,
    title TEXT,
    content TEXT,
    received_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kid_notifs_device ON kid_notifications(device_id, received_at DESC);

-- 15. Web Filter Rules (Keywords & Blocked Domains)
CREATE TABLE IF NOT EXISTS web_filter_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    rule_type VARCHAR(20) NOT NULL, -- 'keyword' or 'domain'
    pattern VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'custom',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(device_id, rule_type, pattern)
);

CREATE INDEX IF NOT EXISTS idx_web_filter_rules_device ON web_filter_rules(device_id);

-- 16. Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    details JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default Super Admin user (Password: Admin@123456)
INSERT INTO users (id, email, password_hash, full_name, role)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'admin@parentalcontrol.local',
    crypt('Admin@123456', gen_salt('bf', 10)),
    'System Administrator',
    'superadmin'
) ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO families (id, name, owner_id)
VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'Admin Family',
    'a0000000-0000-0000-0000-000000000001'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO subscriptions (family_id, tier, max_devices, starts_at, is_active)
VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'family_unlimited',
    99,
    NOW(),
    true
) ON CONFLICT DO NOTHING;
