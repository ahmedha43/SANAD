package domain

import (
	"time"

	"github.com/google/uuid"
)

type UserRole string

const (
	RoleSuperAdmin UserRole = "superadmin"
	RoleAdmin      UserRole = "admin"
	RoleParent     UserRole = "parent"
)

type DeviceStatus string

const (
	StatusOnline  DeviceStatus = "online"
	StatusOffline DeviceStatus = "offline"
	StatusSleep   DeviceStatus = "sleep"
)

type CommandStatus string

const (
	CommandPending   CommandStatus = "pending"
	CommandSent      CommandStatus = "sent"
	CommandDelivered CommandStatus = "delivered"
	CommandExecuted  CommandStatus = "executed"
	CommandFailed    CommandStatus = "failed"
)

type SubscriptionTier string

const (
	TierFree            SubscriptionTier = "free"
	TierBasic           SubscriptionTier = "basic"
	TierPremium         SubscriptionTier = "premium"
	TierFamilyUnlimited SubscriptionTier = "family_unlimited"
)

// User represents Parent or Admin
type User struct {
	ID           uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	Email        string    `gorm:"uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"not null" json:"-"`
	FullName     string    `gorm:"not null" json:"full_name"`
	PhoneNumber  string    `json:"phone_number,omitempty"`
	Role         UserRole  `gorm:"type:user_role;default:'parent'" json:"role"`
	IsActive     bool      `gorm:"default:true" json:"is_active"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`

	Families []Family `gorm:"foreignKey:OwnerID" json:"families,omitempty"`
}

// Family groups parents, children, and devices
type Family struct {
	ID        uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	Name      string    `gorm:"not null" json:"name"`
	OwnerID   uuid.UUID `gorm:"type:uuid;not null" json:"owner_id"`
	Owner     *User     `gorm:"foreignKey:OwnerID" json:"owner,omitempty"`
	CreatedAt time.Time `json:"created_at"`

	Children     []Child       `gorm:"foreignKey:FamilyID" json:"children,omitempty"`
	Devices      []Device      `gorm:"foreignKey:FamilyID" json:"devices,omitempty"`
	Subscription *Subscription `gorm:"foreignKey:FamilyID" json:"subscription,omitempty"`
}

// Child profile
type Child struct {
	ID        uuid.UUID  `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	FamilyID  uuid.UUID  `gorm:"type:uuid;not null" json:"family_id"`
	Name      string     `gorm:"not null" json:"name"`
	AvatarURL string     `json:"avatar_url,omitempty"`
	BirthDate *time.Time `json:"birth_date,omitempty"`
	CreatedAt time.Time  `json:"created_at"`

	Devices   []Device   `gorm:"foreignKey:ChildID" json:"devices,omitempty"`
	Geofences []Geofence `gorm:"foreignKey:ChildID" json:"geofences,omitempty"`
}

// Device represents an Android Kids Agent device
type Device struct {
	ID            uuid.UUID    `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	ChildID       *uuid.UUID   `gorm:"type:uuid" json:"child_id,omitempty"`
	FamilyID      uuid.UUID    `gorm:"type:uuid;not null" json:"family_id"`
	DeviceUID     string       `gorm:"uniqueIndex;not null" json:"device_uid"`
	DeviceName    string       `gorm:"not null" json:"device_name"`
	Model         string       `json:"model,omitempty"`
	OSVersion     string       `json:"os_version,omitempty"`
	OSType        string       `gorm:"default:'android'" json:"os_type,omitempty"`
	AppVersion    string       `json:"app_version,omitempty"`
	BatteryLevel  int          `gorm:"default:100" json:"battery_level"`
	IsCharging    bool         `gorm:"default:false" json:"is_charging"`
	NetworkType   string       `json:"network_type,omitempty"`
	Status        DeviceStatus `gorm:"type:device_status;default:'offline'" json:"status"`
	PairingSecret string       `gorm:"not null" json:"-"`
	FCMToken      string       `json:"-"`
	LastSeenAt         *time.Time   `json:"last_seen_at,omitempty"`
	IsMonitoringPaused bool         `gorm:"default:false" json:"is_monitoring_paused"`
	IsWebFilterEnabled bool         `gorm:"default:true" json:"is_web_filter_enabled"`
	CreatedAt          time.Time    `json:"created_at"`
	UpdatedAt     time.Time    `json:"updated_at"`

	Child           *Child           `gorm:"foreignKey:ChildID" json:"child,omitempty"`
	ScreenTimeRule  *ScreenTimeRule  `gorm:"foreignKey:DeviceID" json:"screen_time_rule,omitempty"`
	LastLocation    *LocationLog     `gorm:"-" json:"last_location,omitempty"`
}

// PairingCode for linking Kid device to Family/Child
type PairingCode struct {
	Code      string    `gorm:"primaryKey;size:6" json:"code"`
	FamilyID  uuid.UUID `gorm:"type:uuid;not null" json:"family_id"`
	ChildID   uuid.UUID `gorm:"type:uuid;not null" json:"child_id"`
	ExpiresAt time.Time `gorm:"not null" json:"expires_at"`
	IsUsed    bool      `gorm:"default:false" json:"is_used"`
}

// LocationLog contains historical and live coordinates
type LocationLog struct {
	ID         int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID   uuid.UUID `gorm:"type:uuid;not null;index:idx_location_device_time" json:"device_id"`
	Latitude   float64   `gorm:"not null" json:"latitude"`
	Longitude  float64   `gorm:"not null" json:"longitude"`
	Accuracy   float32   `json:"accuracy"`
	Altitude   float32   `json:"altitude"`
	Speed      float32   `json:"speed"`
	Bearing    float32   `json:"bearing"`
	RecordedAt time.Time `gorm:"not null;index:idx_location_device_time" json:"recorded_at"`
	CreatedAt  time.Time `json:"created_at"`
}

// Geofence boundary
type Geofence struct {
	ID           uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	ChildID      uuid.UUID `gorm:"type:uuid;not null" json:"child_id"`
	Name         string    `gorm:"not null" json:"name"`
	Latitude     float64   `gorm:"not null" json:"latitude"`
	Longitude    float64   `gorm:"not null" json:"longitude"`
	RadiusMeters int       `gorm:"default:200" json:"radius_meters"`
	AlertOnEntry bool      `gorm:"default:true" json:"alert_on_entry"`
	AlertOnExit  bool      `gorm:"default:true" json:"alert_on_exit"`
	IsActive     bool      `gorm:"default:true" json:"is_active"`
	CreatedAt    time.Time `json:"created_at"`
}

// GeofenceEvent triggered entry or exit
type GeofenceEvent struct {
	ID           int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	GeofenceID   uuid.UUID `gorm:"type:uuid;not null" json:"geofence_id"`
	DeviceID     uuid.UUID `gorm:"type:uuid;not null" json:"device_id"`
	EventType    string    `gorm:"not null" json:"event_type"` // "ENTER" | "EXIT"
	TriggeredAt  time.Time `json:"triggered_at"`
	GeofenceName string    `gorm:"->" json:"geofence_name,omitempty"`
}

// DeviceApp installed apps on Kid's device
type DeviceApp struct {
	ID           uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	DeviceID     uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_device_app_pkg" json:"device_id"`
	PackageName  string    `gorm:"not null;uniqueIndex:idx_device_app_pkg" json:"package_name"`
	AppName      string    `gorm:"not null" json:"app_name"`
	IconURL      string    `json:"icon_url,omitempty"`
	IsSystemApp  bool      `gorm:"default:false" json:"is_system_app"`
	IsBlocked    bool      `gorm:"default:false" json:"is_blocked"`
	CreatedAt    time.Time `json:"created_at"`
}

// AppUsageDaily daily app screen time rollup
type AppUsageDaily struct {
	ID                   int64      `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID             uuid.UUID  `gorm:"type:uuid;not null;uniqueIndex:idx_app_usage_uniq" json:"device_id"`
	PackageName          string     `gorm:"not null;uniqueIndex:idx_app_usage_uniq" json:"package_name"`
	Date                 string     `gorm:"type:date;not null;uniqueIndex:idx_app_usage_uniq" json:"date"`
	UsageDurationSeconds int        `gorm:"default:0" json:"usage_duration_seconds"`
	OpenCount            int        `gorm:"default:0" json:"open_count"`
	LastUsedAt           *time.Time `json:"last_used_at,omitempty"`
}

func (AppUsageDaily) TableName() string {
	return "app_usage_daily"
}

// ScreenTimeRule device limits and sleep times
type ScreenTimeRule struct {
	ID                 uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	DeviceID           uuid.UUID `gorm:"type:uuid;not null;uniqueIndex" json:"device_id"`
	DailyLimitMinutes  int       `gorm:"default:180" json:"daily_limit_minutes"`
	DowntimeStart      string    `json:"downtime_start,omitempty"` // e.g. "21:00"
	DowntimeEnd        string    `json:"downtime_end,omitempty"`   // e.g. "07:00"
	IsActive           bool      `gorm:"default:true" json:"is_active"`
	UpdatedAt          time.Time `json:"updated_at"`
}

// DeviceCommand represents async remote commands
type DeviceCommand struct {
	ID           uuid.UUID     `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	DeviceID     uuid.UUID     `gorm:"type:uuid;not null" json:"device_id"`
	CommandType  string        `gorm:"not null" json:"command_type"`
	Payload      string        `gorm:"type:jsonb;default:'{}'" json:"payload"`
	Status       CommandStatus `gorm:"type:command_status;default:'pending'" json:"status"`
	ErrorMessage string        `json:"error_message,omitempty"`
	ExecutedAt   *time.Time    `json:"executed_at,omitempty"`
	CreatedAt    time.Time     `json:"created_at"`
}

// KidNotification intercepted notification
type KidNotification struct {
	ID          int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID    uuid.UUID `gorm:"type:uuid;not null" json:"device_id"`
	AppName     string    `gorm:"not null" json:"app_name"`
	PackageName string    `gorm:"not null" json:"package_name"`
	Title       string    `json:"title"`
	Content     string    `json:"content"`
	ReceivedAt  time.Time `gorm:"not null" json:"received_at"`
	CreatedAt   time.Time `json:"created_at"`
}

// KidContact represents child's device phone contact
type KidContact struct {
	ID          int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID    uuid.UUID `gorm:"type:uuid;not null;index:idx_kid_contact_dev" json:"device_id"`
	Name        string    `gorm:"not null" json:"name"`
	PhoneNumber string    `gorm:"not null" json:"phone_number"`
	CreatedAt   time.Time `json:"created_at"`
}

// KidSMS represents child's device SMS message
type KidSMS struct {
	ID         int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID   uuid.UUID `gorm:"type:uuid;not null;index:idx_kid_sms_dev" json:"device_id"`
	Sender     string    `gorm:"not null" json:"sender"`
	Body       string    `gorm:"not null" json:"body"`
	IsIncoming bool      `gorm:"default:true" json:"is_incoming"`
	Timestamp  int64     `json:"timestamp"`
	CreatedAt  time.Time `json:"created_at"`
}

// KidFile represents child's device gallery / photo / file info
type KidFile struct {
	ID              int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID        uuid.UUID `gorm:"type:uuid;not null;index:idx_kid_file_dev" json:"device_id"`
	FileName        string    `gorm:"not null" json:"file_name"`
	FilePath        string    `json:"file_path"`
	FileSize        int64     `json:"file_size"`
	MimeType        string    `json:"mime_type"`
	ThumbnailBase64 string    `gorm:"type:text" json:"thumbnail_base64,omitempty"`
	Timestamp       int64     `json:"timestamp"`
	CreatedAt       time.Time `json:"created_at"`
}

// KidCallLog represents child's device phone call log
type KidCallLog struct {
	ID              int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID        uuid.UUID `gorm:"type:uuid;not null;index:idx_kid_call_dev" json:"device_id"`
	Number          string    `gorm:"not null" json:"number"`
	Name            string    `json:"name"`
	CallType        string    `gorm:"not null" json:"call_type"` // INCOMING, OUTGOING, MISSED, REJECTED
	DurationSeconds int       `json:"duration_seconds"`
	Timestamp       int64     `json:"timestamp"`
	CreatedAt       time.Time `json:"created_at"`
}

// RiskAlert represents AI-detected danger / toxicity alert
type RiskAlert struct {
	ID            int64      `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID      uuid.UUID  `gorm:"type:uuid;not null;index:idx_risk_alert_dev" json:"device_id"`
	Category      string     `gorm:"not null" json:"category"` // BULLYING, INAPPROPRIATE, STRANGER, SUBSTANCES, SELF_HARM
	Severity      string     `gorm:"not null" json:"severity"` // CRITICAL, HIGH, MEDIUM
	Snippet       string     `gorm:"not null" json:"snippet"`
	Source        string     `gorm:"not null" json:"source"` // SMS, NOTIFICATION, SEARCH
	MatchedReason string     `gorm:"type:text;default:''" json:"matched_reason"`
	IsSafe        bool       `gorm:"default:false" json:"is_safe"`
	ResolvedAt    *time.Time `json:"resolved_at,omitempty"`
	Timestamp     int64      `json:"timestamp"`
	CreatedAt     time.Time  `json:"created_at"`
}

// RiskSafeRule represents a pattern or source explicitly whitelisted by parent
type RiskSafeRule struct {
	ID        int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID  uuid.UUID `gorm:"type:uuid;not null;index:idx_risk_safe_rules_device" json:"device_id"`
	Pattern   string    `gorm:"type:text;not null" json:"pattern"`
	RuleType  string    `gorm:"type:varchar(50);default:'keyword'" json:"rule_type"`
	CreatedAt time.Time `json:"created_at"`
}

// Subscription holds subscription tier details
type Subscription struct {
	ID               uuid.UUID        `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	FamilyID         uuid.UUID        `gorm:"type:uuid;not null;uniqueIndex" json:"family_id"`
	Family           *Family          `gorm:"foreignKey:FamilyID" json:"family,omitempty"`
	Tier             SubscriptionTier `gorm:"type:subscription_tier;default:'free'" json:"tier"`
	MaxDevices       int              `gorm:"default:2" json:"max_devices"`
	StartsAt         time.Time        `json:"starts_at"`
	ExpiresAt        *time.Time       `json:"expires_at,omitempty"`
	IsActive         bool             `gorm:"default:true" json:"is_active"`
	PaymentReference string           `json:"payment_reference,omitempty"`
	CreatedAt        time.Time        `json:"created_at"`
}

// SubscriptionPlan defines pricing packages, billing cycles, and feature sets
type SubscriptionPlan struct {
	ID           string    `gorm:"primaryKey;size:64" json:"id"`
	Name         string    `gorm:"not null;size:100" json:"name"`
	Tier         string    `gorm:"not null;size:50" json:"tier"`
	Price        float64   `gorm:"not null;default:0" json:"price"`
	Currency     string    `gorm:"not null;default:'USD';size:10" json:"currency"`
	BillingCycle string    `gorm:"not null;default:'monthly';size:20" json:"billing_cycle"` // monthly, yearly, lifetime
	DurationDays int       `gorm:"not null;default:30" json:"duration_days"`
	MaxDevices   int       `gorm:"not null;default:2" json:"max_devices"`
	Features     string    `gorm:"type:text" json:"features"` // JSON array of feature slugs
	IsActive     bool      `gorm:"default:true" json:"is_active"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// AuditLog security tracking
type AuditLog struct {
	ID        int64      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    *uuid.UUID `gorm:"type:uuid" json:"user_id,omitempty"`
	Action    string     `gorm:"not null" json:"action"`
	Resource  string     `gorm:"not null" json:"resource"`
	Details   string     `gorm:"type:jsonb" json:"details,omitempty"`
	IPAddress string     `json:"ip_address,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}

// OfflineSyncRequest payload sent by kids-agent WorkManager when internet reconnects
type OfflineSyncRequest struct {
	Locations  []LocationPayload `json:"locations"`
	Calls      []KidCallLog      `json:"calls"`
	RiskAlerts []RiskAlert       `json:"risk_alerts"`
}

// OfflineSyncResponse response confirming count of synced records
type OfflineSyncResponse struct {
	Success         bool `json:"success"`
	SyncedLocations int  `json:"synced_locations"`
	SyncedCalls     int  `json:"synced_calls"`
	SyncedRisks     int  `json:"synced_risks"`
}

// WebFilterRule represents a keyword or URL domain blocked on kid's device
type WebFilterRule struct {
	ID        uuid.UUID `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	DeviceID  uuid.UUID `gorm:"type:uuid;not null;index:idx_web_filter_rules_device" json:"device_id"`
	RuleType  string    `gorm:"type:varchar(20);not null" json:"rule_type"` // 'keyword' or 'domain'
	Pattern   string    `gorm:"type:varchar(255);not null" json:"pattern"`
	Category  string    `gorm:"type:varchar(50);default:'custom'" json:"category"`
	IsActive  bool      `gorm:"default:true" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}


