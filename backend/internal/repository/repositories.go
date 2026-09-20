package repository

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"gorm.io/gorm"
)

type Repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetDB() *gorm.DB {
	return r.db
}

// User methods
func (r *Repository) CreateUser(ctx context.Context, user *domain.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

func (r *Repository) GetUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).Preload("Families").Where("email = ?", email).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *Repository) GetUserByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	var user domain.User
	err := r.db.WithContext(ctx).Preload("Families").Where("id = ?", id).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// Family methods
func (r *Repository) CreateFamily(ctx context.Context, family *domain.Family) error {
	return r.db.WithContext(ctx).Create(family).Error
}

func (r *Repository) GetFamilyByID(ctx context.Context, id uuid.UUID) (*domain.Family, error) {
	var family domain.Family
	err := r.db.WithContext(ctx).
		Preload("Children").
		Preload("Devices").
		Preload("Subscription").
		Where("id = ?", id).
		First(&family).Error
	if err != nil {
		return nil, err
	}
	return &family, nil
}

func (r *Repository) GetFamiliesByOwnerID(ctx context.Context, ownerID uuid.UUID) ([]domain.Family, error) {
	var families []domain.Family
	err := r.db.WithContext(ctx).
		Preload("Children").
		Preload("Devices").
		Preload("Subscription").
		Where("owner_id = ?", ownerID).
		Find(&families).Error
	return families, err
}

// Child methods
func (r *Repository) CreateChild(ctx context.Context, child *domain.Child) error {
	return r.db.WithContext(ctx).Create(child).Error
}

func (r *Repository) GetChildrenByFamily(ctx context.Context, familyID uuid.UUID) ([]domain.Child, error) {
	var children []domain.Child
	err := r.db.WithContext(ctx).Preload("Devices").Where("family_id = ?", familyID).Find(&children).Error
	return children, err
}

// Device methods
func (r *Repository) CreateDevice(ctx context.Context, device *domain.Device) error {
	return r.db.WithContext(ctx).Create(device).Error
}

func (r *Repository) GetDeviceByUID(ctx context.Context, uid string) (*domain.Device, error) {
	var dev domain.Device
	err := r.db.WithContext(ctx).Preload("Child").Where("device_uid = ?", uid).First(&dev).Error
	if err != nil {
		return nil, err
	}
	return &dev, nil
}

func (r *Repository) GetDeviceByID(ctx context.Context, id uuid.UUID) (*domain.Device, error) {
	var dev domain.Device
	err := r.db.WithContext(ctx).Preload("Child").Where("id = ?", id).First(&dev).Error
	if err != nil {
		return nil, err
	}
	return &dev, nil
}

func (r *Repository) UpdateDeviceStatus(ctx context.Context, deviceID uuid.UUID, status domain.DeviceStatus, battery int, isCharging bool, networkType string) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&domain.Device{}).
		Where("id = ?", deviceID).
		Updates(map[string]interface{}{
			"status":        status,
			"battery_level": battery,
			"is_charging":   isCharging,
			"network_type":  networkType,
			"last_seen_at":  now,
		}).Error
}

func (r *Repository) SetDeviceMonitoringPaused(ctx context.Context, deviceID uuid.UUID, isPaused bool) error {
	return r.db.WithContext(ctx).Model(&domain.Device{}).
		Where("id = ?", deviceID).
		Update("is_monitoring_paused", isPaused).Error
}

func (r *Repository) GetDevicesByFamilyID(ctx context.Context, familyID uuid.UUID) ([]domain.Device, error) {
	var devices []domain.Device
	err := r.db.WithContext(ctx).Preload("Child").Where("family_id = ?", familyID).Find(&devices).Error
	return devices, err
}

// DeleteDeviceCompletely removes a device and executes a complete cascade wipe across all tables
func (r *Repository) DeleteDeviceCompletely(ctx context.Context, deviceID uuid.UUID) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 1. Delete all operational data & sensor logs
		tx.Where("device_id = ?", deviceID).Delete(&domain.LocationLog{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.GeofenceEvent{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.DeviceApp{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.AppUsageDaily{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.KidCallLog{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.KidSMS{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.KidContact{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.KidNotification{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.KidFile{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.RiskAlert{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.RiskSafeRule{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.ScreenTimeRule{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.WebFilterRule{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.BrowserHistory{})
		tx.Where("device_id = ?", deviceID).Delete(&domain.DeviceCommand{})

		// 2. Delete any pairing codes for this device's child
		tx.Exec("DELETE FROM pairing_codes WHERE child_id IN (SELECT child_id FROM devices WHERE id = ?)", deviceID)

		// 3. Delete the device entity itself
		if err := tx.Where("id = ?", deviceID).Delete(&domain.Device{}).Error; err != nil {
			return err
		}
		return nil
	})
}

// DeleteChildCompletely removes a child and cascades to wipe any linked devices, pairing codes, geofences, and records
func (r *Repository) DeleteChildCompletely(ctx context.Context, childID uuid.UUID) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var devices []domain.Device
		if err := tx.Where("child_id = ?", childID).Find(&devices).Error; err == nil {
			for _, dev := range devices {
				tx.Where("device_id = ?", dev.ID).Delete(&domain.LocationLog{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.GeofenceEvent{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.DeviceApp{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.AppUsageDaily{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.KidCallLog{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.KidSMS{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.KidContact{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.KidNotification{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.KidFile{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.RiskAlert{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.RiskSafeRule{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.ScreenTimeRule{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.WebFilterRule{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.BrowserHistory{})
				tx.Where("device_id = ?", dev.ID).Delete(&domain.DeviceCommand{})
				tx.Where("id = ?", dev.ID).Delete(&domain.Device{})
			}
		}

		tx.Where("child_id = ?", childID).Delete(&domain.PairingCode{})
		tx.Where("child_id = ?", childID).Delete(&domain.Geofence{})

		return tx.Where("id = ?", childID).Delete(&domain.Child{}).Error
	})
}

// Pairing Code
func (r *Repository) SavePairingCode(ctx context.Context, pc *domain.PairingCode) error {
	return r.db.WithContext(ctx).Save(pc).Error
}

func (r *Repository) GetValidPairingCode(ctx context.Context, code string) (*domain.PairingCode, error) {
	var pc domain.PairingCode
	err := r.db.WithContext(ctx).
		Where("code = ? AND is_used = false AND expires_at > ?", code, time.Now()).
		First(&pc).Error
	if err != nil {
		return nil, err
	}
	return &pc, nil
}

func (r *Repository) MarkPairingCodeUsed(ctx context.Context, code string) error {
	return r.db.WithContext(ctx).Model(&domain.PairingCode{}).
		Where("code = ?", code).
		Update("is_used", true).Error
}

// Location
func (r *Repository) SaveLocation(ctx context.Context, loc *domain.LocationLog) error {
	return r.db.WithContext(ctx).Create(loc).Error
}

func (r *Repository) GetLatestLocation(ctx context.Context, deviceID uuid.UUID) (*domain.LocationLog, error) {
	var loc domain.LocationLog
	err := r.db.WithContext(ctx).
		Where("device_id = ?", deviceID).
		Order("recorded_at DESC").
		First(&loc).Error
	if err != nil {
		return nil, err
	}
	return &loc, nil
}

func (r *Repository) GetLocationHistory(ctx context.Context, deviceID uuid.UUID, since time.Time) ([]domain.LocationLog, error) {
	var logs []domain.LocationLog
	err := r.db.WithContext(ctx).
		Where("device_id = ? AND recorded_at >= ?", deviceID, since).
		Order("recorded_at ASC").
		Find(&logs).Error
	return logs, err
}

// Geofences
func (r *Repository) CreateGeofence(ctx context.Context, g *domain.Geofence) error {
	return r.db.WithContext(ctx).Create(g).Error
}

func (r *Repository) GetGeofencesByChild(ctx context.Context, childID uuid.UUID) ([]domain.Geofence, error) {
	var gfs []domain.Geofence
	err := r.db.WithContext(ctx).Where("child_id = ? AND is_active = true", childID).Find(&gfs).Error
	return gfs, err
}

func (r *Repository) RecordGeofenceEvent(ctx context.Context, event *domain.GeofenceEvent) error {
	return r.db.WithContext(ctx).Create(event).Error
}

func (r *Repository) GetGeofenceEventsByChild(ctx context.Context, childID uuid.UUID, limit int) ([]domain.GeofenceEvent, error) {
	var events []domain.GeofenceEvent
	err := r.db.WithContext(ctx).
		Table("geofence_events").
		Select("geofence_events.*, geofences.name as geofence_name").
		Joins("JOIN geofences ON geofences.id = geofence_events.geofence_id").
		Where("geofences.child_id = ?", childID).
		Order("geofence_events.triggered_at DESC").
		Limit(limit).
		Find(&events).Error
	return events, err
}

// Apps & Screen Time
func (r *Repository) UpsertDeviceApps(ctx context.Context, apps []domain.DeviceApp) error {
	for _, app := range apps {
		var existing domain.DeviceApp
		err := r.db.WithContext(ctx).
			Where("device_id = ? AND package_name = ?", app.DeviceID, app.PackageName).
			First(&existing).Error
		if err == gorm.ErrRecordNotFound {
			if err := r.db.WithContext(ctx).Create(&app).Error; err != nil {
				return err
			}
		} else if err == nil {
			r.db.WithContext(ctx).Model(&existing).Updates(map[string]interface{}{
				"app_name": app.AppName,
				"icon_url": app.IconURL,
			})
		}
	}
	return nil
}

func (r *Repository) GetDeviceApps(ctx context.Context, deviceID uuid.UUID) ([]domain.DeviceApp, error) {
	var apps []domain.DeviceApp
	err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).Find(&apps).Error
	return apps, err
}

func (r *Repository) SetAppBlocked(ctx context.Context, deviceID uuid.UUID, packageName string, blocked bool) error {
	return r.db.WithContext(ctx).Model(&domain.DeviceApp{}).
		Where("device_id = ? AND package_name = ?", deviceID, packageName).
		Update("is_blocked", blocked).Error
}

func (r *Repository) UpsertDailyUsage(ctx context.Context, usage *domain.AppUsageDaily) error {
	var existing domain.AppUsageDaily
	err := r.db.WithContext(ctx).
		Where("device_id = ? AND package_name = ? AND date = ?", usage.DeviceID, usage.PackageName, usage.Date).
		First(&existing).Error
	if err == gorm.ErrRecordNotFound {
		return r.db.WithContext(ctx).Create(usage).Error
	}
	return r.db.WithContext(ctx).Model(&domain.AppUsageDaily{}).
		Where("id = ?", existing.ID).
		Updates(map[string]interface{}{
			"usage_duration_seconds": usage.UsageDurationSeconds,
			"open_count":            usage.OpenCount,
			"last_used_at":          usage.LastUsedAt,
		}).Error
}

func (r *Repository) GetUsageByDate(ctx context.Context, deviceID uuid.UUID, date string) ([]domain.AppUsageDaily, error) {
	var stats []domain.AppUsageDaily
	err := r.db.WithContext(ctx).
		Where("device_id = ? AND date = ?", deviceID, date).
		Order("usage_duration_seconds DESC").
		Find(&stats).Error
	return stats, err
}

// Commands
func (r *Repository) CreateCommand(ctx context.Context, cmd *domain.DeviceCommand) error {
	return r.db.WithContext(ctx).Create(cmd).Error
}

func (r *Repository) UpdateCommandStatus(ctx context.Context, cmdID uuid.UUID, status domain.CommandStatus, errMsg string) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&domain.DeviceCommand{}).
		Where("id = ?", cmdID).
		Updates(map[string]interface{}{
			"status":        status,
			"error_message": errMsg,
			"executed_at":   &now,
		}).Error
}

// Notifications
func (r *Repository) SaveKidNotification(ctx context.Context, notif *domain.KidNotification) error {
	return r.db.WithContext(ctx).Create(notif).Error
}

func (r *Repository) GetKidNotifications(ctx context.Context, deviceID uuid.UUID, limit int) ([]domain.KidNotification, error) {
	var notifs []domain.KidNotification
	err := r.db.WithContext(ctx).
		Where("device_id = ?", deviceID).
		Order("received_at DESC").
		Limit(limit).
		Find(&notifs).Error
	return notifs, err
}

// Screen Time Rules
func (r *Repository) GetScreenTimeRule(ctx context.Context, deviceID uuid.UUID) (*domain.ScreenTimeRule, error) {
	var rule domain.ScreenTimeRule
	err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).First(&rule).Error
	if err != nil {
		return nil, err
	}
	return &rule, nil
}

func (r *Repository) UpsertScreenTimeRule(ctx context.Context, rule *domain.ScreenTimeRule) error {
	var existing domain.ScreenTimeRule
	err := r.db.WithContext(ctx).Where("device_id = ?", rule.DeviceID).First(&existing).Error
	if err == gorm.ErrRecordNotFound {
		return r.db.WithContext(ctx).Create(rule).Error
	}
	return r.db.WithContext(ctx).Model(&existing).Updates(map[string]interface{}{
		"daily_limit_minutes": rule.DailyLimitMinutes,
		"downtime_start":      rule.DowntimeStart,
		"downtime_end":        rule.DowntimeEnd,
		"is_active":           rule.IsActive,
		"updated_at":          time.Now(),
	}).Error
}

// Geofence Delete
func (r *Repository) DeleteGeofence(ctx context.Context, geofenceID uuid.UUID) error {
	return r.db.WithContext(ctx).Where("id = ?", geofenceID).Delete(&domain.Geofence{}).Error
}

// Kid Contacts
func (r *Repository) UpsertKidContacts(ctx context.Context, deviceID uuid.UUID, contacts []domain.KidContact) error {
	_ = r.db.WithContext(ctx).Where("device_id = ?", deviceID).Delete(&domain.KidContact{}).Error
	if len(contacts) == 0 {
		return nil
	}
	for i := range contacts {
		contacts[i].DeviceID = deviceID
		contacts[i].CreatedAt = time.Now()
	}
	return r.db.WithContext(ctx).Create(&contacts).Error
}

func (r *Repository) GetKidContacts(ctx context.Context, deviceID uuid.UUID) ([]domain.KidContact, error) {
	var contacts []domain.KidContact
	err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).Order("name ASC").Find(&contacts).Error
	return contacts, err
}

// Kid SMS
func (r *Repository) SaveKidSMSList(ctx context.Context, deviceID uuid.UUID, messages []domain.KidSMS) error {
	_ = r.db.WithContext(ctx).Where("device_id = ?", deviceID).Delete(&domain.KidSMS{}).Error
	if len(messages) == 0 {
		return nil
	}
	for i := range messages {
		messages[i].DeviceID = deviceID
		messages[i].CreatedAt = time.Now()
	}
	return r.db.WithContext(ctx).Create(&messages).Error
}

func (r *Repository) GetKidSMS(ctx context.Context, deviceID uuid.UUID, limit int) ([]domain.KidSMS, error) {
	var messages []domain.KidSMS
	err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).Order("timestamp DESC").Limit(limit).Find(&messages).Error
	return messages, err
}

// Kid Files
func (r *Repository) SaveKidFilesList(ctx context.Context, deviceID uuid.UUID, files []domain.KidFile) error {
	_ = r.db.WithContext(ctx).Where("device_id = ?", deviceID).Delete(&domain.KidFile{}).Error
	if len(files) == 0 {
		return nil
	}
	for i := range files {
		files[i].DeviceID = deviceID
		files[i].CreatedAt = time.Now()
	}
	return r.db.WithContext(ctx).Create(&files).Error
}

func (r *Repository) GetKidFiles(ctx context.Context, deviceID uuid.UUID, limit int) ([]domain.KidFile, error) {
	var files []domain.KidFile
	err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).Order("timestamp DESC").Limit(limit).Find(&files).Error
	return files, err
}

// Kid Call Logs
func (r *Repository) SaveKidCallLogs(ctx context.Context, deviceID uuid.UUID, calls []domain.KidCallLog) error {
	_ = r.db.WithContext(ctx).Where("device_id = ?", deviceID).Delete(&domain.KidCallLog{}).Error
	if len(calls) == 0 {
		return nil
	}
	for i := range calls {
		calls[i].DeviceID = deviceID
		calls[i].CreatedAt = time.Now()
	}
	return r.db.WithContext(ctx).Create(&calls).Error
}

func (r *Repository) GetKidCallLogs(ctx context.Context, deviceID uuid.UUID, limit int) ([]domain.KidCallLog, error) {
	var calls []domain.KidCallLog
	err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).Order("timestamp DESC").Limit(limit).Find(&calls).Error
	return calls, err
}

// Risk Alerts (AI Danger Scanner)
func (r *Repository) SaveRiskAlert(ctx context.Context, alert *domain.RiskAlert) error {
	alert.CreatedAt = time.Now()
	return r.db.WithContext(ctx).Create(alert).Error
}

func (r *Repository) GetRiskAlerts(ctx context.Context, deviceID uuid.UUID, limit int) ([]domain.RiskAlert, error) {
	var alerts []domain.RiskAlert
	err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).Order("timestamp DESC").Limit(limit).Find(&alerts).Error
	return alerts, err
}

func (r *Repository) MarkRiskAlertSafe(ctx context.Context, alertID int64, deviceID uuid.UUID) (*domain.RiskAlert, error) {
	var alert domain.RiskAlert
	if err := r.db.WithContext(ctx).Where("id = ? AND device_id = ?", alertID, deviceID).First(&alert).Error; err != nil {
		return nil, err
	}
	now := time.Now()
	alert.IsSafe = true
	alert.ResolvedAt = &now
	if err := r.db.WithContext(ctx).Save(&alert).Error; err != nil {
		return nil, err
	}

	pattern := alert.Snippet
	if pattern == "" {
		pattern = alert.Category
	}
	var count int64
	r.db.WithContext(ctx).Model(&domain.RiskSafeRule{}).
		Where("device_id = ? AND pattern = ?", deviceID, pattern).
		Count(&count)
	if count == 0 {
		rule := &domain.RiskSafeRule{
			DeviceID:  deviceID,
			Pattern:   pattern,
			RuleType:  "phrase",
			CreatedAt: now,
		}
		_ = r.db.WithContext(ctx).Create(rule).Error
	}

	return &alert, nil
}

func (r *Repository) GetSafeRules(ctx context.Context, deviceID uuid.UUID) ([]domain.RiskSafeRule, error) {
	var rules []domain.RiskSafeRule
	err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).Order("created_at DESC").Find(&rules).Error
	return rules, err
}

func (r *Repository) AddSafeRule(ctx context.Context, rule *domain.RiskSafeRule) error {
	rule.CreatedAt = time.Now()
	return r.db.WithContext(ctx).Create(rule).Error
}

// Subscriptions
func (r *Repository) CreateSubscription(ctx context.Context, sub *domain.Subscription) error {
	return r.db.WithContext(ctx).Create(sub).Error
}

func (r *Repository) GetSubscriptionByFamilyID(ctx context.Context, familyID uuid.UUID) (*domain.Subscription, error) {
	var sub domain.Subscription
	err := r.db.WithContext(ctx).Where("family_id = ?", familyID).First(&sub).Error
	if err != nil {
		return nil, err
	}
	return &sub, nil
}

// Admin Methods
func (r *Repository) GetAllUsers(ctx context.Context) ([]domain.User, error) {
	var users []domain.User
	err := r.db.WithContext(ctx).
		Preload("Families.Subscription").
		Preload("Families.Children").
		Preload("Families.Devices").
		Order("created_at DESC").
		Find(&users).Error
	return users, err
}

func (r *Repository) GetAllDevices(ctx context.Context) ([]domain.Device, error) {
	var devices []domain.Device
	err := r.db.WithContext(ctx).
		Preload("Child").
		Order("created_at DESC").
		Find(&devices).Error
	return devices, err
}

func (r *Repository) GetAllSubscriptions(ctx context.Context) ([]domain.Subscription, error) {
	var subs []domain.Subscription
	err := r.db.WithContext(ctx).
		Preload("Family.Owner").
		Preload("Family.Devices").
		Order("created_at DESC").
		Find(&subs).Error
	return subs, err
}

func (r *Repository) GetSubscriptionByID(ctx context.Context, id uuid.UUID) (*domain.Subscription, error) {
	var sub domain.Subscription
	err := r.db.WithContext(ctx).
		Preload("Family.Owner").
		Preload("Family.Devices").
		Where("id = ?", id).
		First(&sub).Error
	if err != nil {
		return nil, err
	}
	return &sub, nil
}

func (r *Repository) UpdateSubscription(ctx context.Context, sub *domain.Subscription) error {
	return r.db.WithContext(ctx).Save(sub).Error
}

func (r *Repository) GetAllPlans(ctx context.Context) ([]domain.SubscriptionPlan, error) {
	var plans []domain.SubscriptionPlan
	err := r.db.WithContext(ctx).
		Order("price ASC").
		Find(&plans).Error
	return plans, err
}

func (r *Repository) GetPlanByID(ctx context.Context, id string) (*domain.SubscriptionPlan, error) {
	var plan domain.SubscriptionPlan
	err := r.db.WithContext(ctx).
		Where("id = ?", id).
		First(&plan).Error
	if err != nil {
		return nil, err
	}
	return &plan, nil
}

func (r *Repository) SavePlan(ctx context.Context, plan *domain.SubscriptionPlan) error {
	return r.db.WithContext(ctx).Save(plan).Error
}

func (r *Repository) DeletePlan(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Where("id = ?", id).Delete(&domain.SubscriptionPlan{}).Error
}

func (r *Repository) LogAuditEvent(ctx context.Context, action, resource, details string, userID *uuid.UUID, ip string) error {
	log := domain.AuditLog{
		UserID:    userID,
		Action:    action,
		Resource:  resource,
		Details:   details,
		IPAddress: ip,
		CreatedAt: time.Now(),
	}
	return r.db.WithContext(ctx).Create(&log).Error
}

func (r *Repository) GetAuditLogs(ctx context.Context, limit int) ([]domain.AuditLog, error) {
	var logs []domain.AuditLog
	err := r.db.WithContext(ctx).
		Order("created_at DESC").
		Limit(limit).
		Find(&logs).Error
	return logs, err
}

func (r *Repository) GetAdminStats(ctx context.Context) (map[string]int64, error) {
	var totalUsers, totalChildren, totalDevices, totalSubs int64
	r.db.WithContext(ctx).Model(&domain.User{}).Count(&totalUsers)
	r.db.WithContext(ctx).Model(&domain.Child{}).Count(&totalChildren)
	r.db.WithContext(ctx).Model(&domain.Device{}).Count(&totalDevices)
	r.db.WithContext(ctx).Model(&domain.Subscription{}).Where("is_active = ?", true).Count(&totalSubs)

	return map[string]int64{
		"total_parents":         totalUsers,
		"total_children":        totalChildren,
		"total_devices":         totalDevices,
		"active_subscriptions": totalSubs,
	}, nil
}

// Web Filter repository methods

func (r *Repository) GetWebFilterRules(ctx context.Context, deviceID uuid.UUID) ([]domain.WebFilterRule, error) {
	var rules []domain.WebFilterRule
	err := r.db.WithContext(ctx).
		Where("device_id = ?", deviceID).
		Order("created_at DESC").
		Find(&rules).Error
	return rules, err
}

func (r *Repository) GetActiveWebFilterRules(ctx context.Context, deviceID uuid.UUID) ([]domain.WebFilterRule, error) {
	var rules []domain.WebFilterRule
	err := r.db.WithContext(ctx).
		Where("device_id = ? AND is_active = ?", deviceID, true).
		Find(&rules).Error
	return rules, err
}

func (r *Repository) CreateWebFilterRule(ctx context.Context, rule *domain.WebFilterRule) error {
	return r.db.WithContext(ctx).
		Where(domain.WebFilterRule{DeviceID: rule.DeviceID, RuleType: rule.RuleType, Pattern: rule.Pattern}).
		Assign(domain.WebFilterRule{Category: rule.Category, IsActive: rule.IsActive, UpdatedAt: time.Now()}).
		FirstOrCreate(rule).Error
}

func (r *Repository) ToggleWebFilterRule(ctx context.Context, ruleID uuid.UUID, isActive bool) error {
	return r.db.WithContext(ctx).
		Model(&domain.WebFilterRule{}).
		Where("id = ?", ruleID).
		Updates(map[string]interface{}{
			"is_active":  isActive,
			"updated_at": time.Now(),
		}).Error
}

func (r *Repository) DeleteWebFilterRule(ctx context.Context, ruleID uuid.UUID) error {
	return r.db.WithContext(ctx).
		Where("id = ?", ruleID).
		Delete(&domain.WebFilterRule{}).Error
}

func (r *Repository) ToggleAllWebFilterRules(ctx context.Context, deviceID uuid.UUID, isActive bool) error {
	return r.db.WithContext(ctx).
		Model(&domain.WebFilterRule{}).
		Where("device_id = ?", deviceID).
		Updates(map[string]interface{}{
			"is_active":  isActive,
			"updated_at": time.Now(),
		}).Error
}

func (r *Repository) SetDeviceWebFilterEnabled(ctx context.Context, deviceID uuid.UUID, enabled bool) error {
	return r.db.WithContext(ctx).
		Model(&domain.Device{}).
		Where("id = ?", deviceID).
		Updates(map[string]interface{}{
			"is_web_filter_enabled": enabled,
			"updated_at":            time.Now(),
		}).Error
}

func (r *Repository) SeedDefaultWebFilterRules(ctx context.Context, deviceID uuid.UUID) error {
	defaultRules := []domain.WebFilterRule{
		// Adult - Keywords
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "porn", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "xxx", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "sex", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "adult", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "nude", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "nsfw", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "erotic", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "hentai", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "onlyfans", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "webcam sex", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "إباحي", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "جنس", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "سكس", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "عري", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "نيك", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "مؤخرة", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "ثدي", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "افلام جنسية", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "صور عارية", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "شيميل", Category: "adult", IsActive: true},

		// Adult - Domains
		{DeviceID: deviceID, RuleType: "domain", Pattern: "pornhub.com", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "xvideos.com", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "xnxx.com", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "xhamster.com", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "chaturbate.com", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "onlyfans.com", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "redtube.com", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "youporn.com", Category: "adult", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "stripchat.com", Category: "adult", IsActive: true},

		// Gambling - Keywords
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "casino", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "betting", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "gambling", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "poker", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "roulette", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "slots", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "jackpot", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "قمار", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "مراهنات", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "كازينو", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "بوكر", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "روليت", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "يانصيب", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "رهان رياضي", Category: "gambling", IsActive: true},

		// Gambling - Domains
		{DeviceID: deviceID, RuleType: "domain", Pattern: "1xbet.com", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "bet365.com", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "bwin.com", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "pokerstars.com", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "stake.com", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "melbet.com", Category: "gambling", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "888casino.com", Category: "gambling", IsActive: true},

		// Drugs - Keywords
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "buy weed", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "cocaine", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "heroin", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "narcotics", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "ecstasy", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "meth", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "buy liquor online", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "شراء مخدرات", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "حشيش", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "كوكايين", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "هيروين", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "كبتاجون", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "ماريجوانا", Category: "drugs", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "شراء خمور", Category: "drugs", IsActive: true},

		// Violence - Keywords
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "suicide methods", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "how to commit suicide", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "make a bomb", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "buy weapons online", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "self harm", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "طريقة الانتحار", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "كيف انتحر", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "صناعة قنبلة", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "شراء سلاح", Category: "violence", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "ايذاء النفس", Category: "violence", IsActive: true},

		// Bypass & Proxy - Keywords & Domains
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "free proxy", Category: "bypass", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "bypass web filter", Category: "bypass", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "كسر الحجب", Category: "bypass", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "تخطي الحظر", Category: "bypass", IsActive: true},
		{DeviceID: deviceID, RuleType: "keyword", Pattern: "فتح المواقع المحجوبة", Category: "bypass", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "proxysite.com", Category: "bypass", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "kproxy.com", Category: "bypass", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "croxyproxy.com", Category: "bypass", IsActive: true},
		{DeviceID: deviceID, RuleType: "domain", Pattern: "hide.me", Category: "bypass", IsActive: true},
	}

	for _, rule := range defaultRules {
		r.CreateWebFilterRule(ctx, &rule)
	}
	return nil
}

// =========================================================================
// Browser History & Search Intelligence Repositories
// =========================================================================

// SaveBrowserHistoryBatch processes and inserts a batch of history items from agents
func (r *Repository) SaveBrowserHistoryBatch(ctx context.Context, deviceID uuid.UUID, items []domain.BrowserHistoryPayload) (int, error) {
	if len(items) == 0 {
		return 0, nil
	}

	activeRules, _ := r.GetActiveWebFilterRules(ctx, deviceID)

	insertedCount := 0
	for _, item := range items {
		cleanURL := strings.TrimSpace(item.URL)
		if cleanURL == "" || strings.HasPrefix(cleanURL, "about:") || strings.HasPrefix(cleanURL, "chrome://") || strings.HasPrefix(cleanURL, "edge://") {
			continue
		}

		domainName, isSearch, engine, searchParam := domain.ExtractDomainAndSearch(cleanURL)
		if domainName == "" {
			continue
		}

		// Check if URL/domain matches any blocked rule
		isBlocked := false
		lowerURL := strings.ToLower(cleanURL)
		for _, rule := range activeRules {
			pat := strings.ToLower(strings.TrimSpace(rule.Pattern))
			if pat != "" && strings.Contains(lowerURL, pat) {
				isBlocked = true
				break
			}
		}

		// Calculate visit time
		var visitTime time.Time
		if item.Timestamp > 0 {
			if item.Timestamp > 1e11 {
				visitTime = time.UnixMilli(item.Timestamp)
			} else {
				visitTime = time.Unix(item.Timestamp, 0)
			}
		} else {
			visitTime = time.Now()
		}

		browserName := strings.ToLower(strings.TrimSpace(item.Browser))
		if browserName == "" {
			browserName = "chrome"
		}

		record := domain.BrowserHistory{
			DeviceID:        deviceID,
			Browser:         browserName,
			URL:             cleanURL,
			Title:           strings.TrimSpace(item.Title),
			Domain:          domainName,
			VisitCount:      item.VisitCount,
			DurationSeconds: item.DurationSeconds,
			IsSearch:        isSearch,
			SearchQuery:     searchParam,
			SearchEngine:    engine,
			Category:        "general",
			IsBlocked:       isBlocked,
			VisitTime:       visitTime,
			CreatedAt:       time.Now(),
		}
		if record.VisitCount < 1 {
			record.VisitCount = 1
		}

		// Deduplicate: avoid re-inserting exact same URL visited within the same 60 seconds
		var existing domain.BrowserHistory
		windowStart := visitTime.Add(-60 * time.Second)
		windowEnd := visitTime.Add(60 * time.Second)
		err := r.db.WithContext(ctx).
			Where("device_id = ? AND url = ? AND visit_time BETWEEN ? AND ?", deviceID, cleanURL, windowStart, windowEnd).
			First(&existing).Error

		if err == nil && existing.ID > 0 {
			// Update visit count
			r.db.WithContext(ctx).Model(&existing).Updates(map[string]interface{}{
				"visit_count":      existing.VisitCount + 1,
				"duration_seconds": existing.DurationSeconds + item.DurationSeconds,
			})
			continue
		}

		if err := r.db.WithContext(ctx).Create(&record).Error; err == nil {
			insertedCount++
		}
	}

	return insertedCount, nil
}

// GetBrowserHistory lists history records with filters and search query
func (r *Repository) GetBrowserHistory(ctx context.Context, deviceID uuid.UUID, limit, offset int, filter, search string) ([]domain.BrowserHistory, int64, error) {
	var records []domain.BrowserHistory
	var total int64

	q := r.db.WithContext(ctx).Model(&domain.BrowserHistory{}).Where("device_id = ?", deviceID)

	if filter == "searches" {
		q = q.Where("is_search = ?", true)
	} else if filter == "blocked" {
		q = q.Where("is_blocked = ?", true)
	} else if filter == "chrome" || filter == "edge" || filter == "firefox" || filter == "samsung" {
		q = q.Where("browser = ?", filter)
	}

	if search != "" {
		s := "%" + strings.ToLower(search) + "%"
		q = q.Where("LOWER(title) LIKE ? OR LOWER(url) LIKE ? OR LOWER(domain) LIKE ? OR LOWER(search_query) LIKE ?", s, s, s, s)
	}

	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if limit <= 0 || limit > 500 {
		limit = 100
	}

	err := q.Order("visit_time DESC").Limit(limit).Offset(offset).Find(&records).Error
	return records, total, err
}

// GetTopSearchQueries aggregates top searches in Google, YouTube, Bing, etc.
func (r *Repository) GetTopSearchQueries(ctx context.Context, deviceID uuid.UUID, limit int) ([]map[string]interface{}, error) {
	if limit <= 0 {
		limit = 10
	}

	type Result struct {
		SearchQuery  string    `gorm:"column:search_query"`
		SearchEngine string    `gorm:"column:search_engine"`
		Count        int       `gorm:"column:total_count"`
		LastSearched time.Time `gorm:"column:last_searched"`
	}

	var rawResults []Result
	err := r.db.WithContext(ctx).Model(&domain.BrowserHistory{}).
		Select("search_query, search_engine, COUNT(*) as total_count, MAX(visit_time) as last_searched").
		Where("device_id = ? AND is_search = ? AND search_query != ''", deviceID, true).
		Group("search_query, search_engine").
		Order("total_count DESC, last_searched DESC").
		Limit(limit).
		Scan(&rawResults).Error

	if err != nil {
		return nil, err
	}

	formatted := make([]map[string]interface{}, len(rawResults))
	for i, res := range rawResults {
		formatted[i] = map[string]interface{}{
			"query":         res.SearchQuery,
			"engine":        res.SearchEngine,
			"count":         res.Count,
			"last_searched": res.LastSearched,
		}
	}

	return formatted, nil
}

// GetTopVisitedDomains aggregates most frequently visited websites
func (r *Repository) GetTopVisitedDomains(ctx context.Context, deviceID uuid.UUID, limit int) ([]map[string]interface{}, error) {
	if limit <= 0 {
		limit = 8
	}

	type Result struct {
		Domain      string    `gorm:"column:domain"`
		TotalVisits int       `gorm:"column:total_visits"`
		LastVisit   time.Time `gorm:"column:last_visit"`
	}

	var rawResults []Result
	err := r.db.WithContext(ctx).Model(&domain.BrowserHistory{}).
		Select("domain, SUM(visit_count) as total_visits, MAX(visit_time) as last_visit").
		Where("device_id = ? AND domain != ''", deviceID).
		Group("domain").
		Order("total_visits DESC, last_visit DESC").
		Limit(limit).
		Scan(&rawResults).Error

	if err != nil {
		return nil, err
	}

	formatted := make([]map[string]interface{}, len(rawResults))
	for i, res := range rawResults {
		formatted[i] = map[string]interface{}{
			"domain":       res.Domain,
			"total_visits": res.TotalVisits,
			"last_visit":   res.LastVisit,
		}
	}

	return formatted, nil
}

// GetBrowserHistoryStats returns high-level metric counts for dashboard cards
func (r *Repository) GetBrowserHistoryStats(ctx context.Context, deviceID uuid.UUID) (map[string]interface{}, error) {
	var totalVisits int64
	var totalSearches int64
	var totalBlocked int64

	todayStart := time.Now().Truncate(24 * time.Hour)

	r.db.WithContext(ctx).Model(&domain.BrowserHistory{}).
		Where("device_id = ? AND visit_time >= ?", deviceID, todayStart).
		Count(&totalVisits)

	r.db.WithContext(ctx).Model(&domain.BrowserHistory{}).
		Where("device_id = ? AND is_search = ?", deviceID, true).
		Count(&totalSearches)

	r.db.WithContext(ctx).Model(&domain.BrowserHistory{}).
		Where("device_id = ? AND is_blocked = ?", deviceID, true).
		Count(&totalBlocked)

	return map[string]interface{}{
		"today_visits":   totalVisits,
		"total_searches": totalSearches,
		"total_blocked":  totalBlocked,
	}, nil
}

// ClearBrowserHistory wipes history for a given device
func (r *Repository) ClearBrowserHistory(ctx context.Context, deviceID uuid.UUID) error {
	return r.db.WithContext(ctx).Where("device_id = ?", deviceID).Delete(&domain.BrowserHistory{}).Error
}
