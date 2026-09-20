package handler

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
	"github.com/parental-control/backend/internal/service"
)

type DeviceHandler struct {
	repo            *repository.Repository
	pairingService  *service.PairingService
	deviceService   *service.DeviceService
	locationService *service.LocationService
	wsHub           *WSHub
}

func NewDeviceHandler(repo *repository.Repository, pairingService *service.PairingService, deviceService *service.DeviceService, locationService *service.LocationService, wsHub *WSHub) *DeviceHandler {
	return &DeviceHandler{
		repo:            repo,
		pairingService:  pairingService,
		deviceService:   deviceService,
		locationService: locationService,
		wsHub:           wsHub,
	}
}

// ListDevices returns all devices in parent's family
func (h *DeviceHandler) ListDevices(c *fiber.Ctx) error {
	familyID, ok := c.Locals("family_id").(uuid.UUID)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Family not found in session"})
	}

	devices, err := h.repo.GetDevicesByFamilyID(c.Context(), familyID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	// Populate latest locations & live online status
	for i := range devices {
		loc, _ := h.repo.GetLatestLocation(c.Context(), devices[i].ID)
		devices[i].LastLocation = loc
		if h.wsHub != nil {
			if h.wsHub.IsKidOnline(devices[i].ID.String()) {
				devices[i].Status = domain.StatusOnline
			} else {
				devices[i].Status = domain.StatusOffline
			}
		}
	}

	return c.JSON(devices)
}

// ListChildren returns all children registered in parent's family
func (h *DeviceHandler) ListChildren(c *fiber.Ctx) error {
	familyID, ok := c.Locals("family_id").(uuid.UUID)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Family not found in session"})
	}

	children, err := h.repo.GetChildrenByFamily(c.Context(), familyID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(children)
}


// CreateChild adds a new child profile to family
func (h *DeviceHandler) CreateChild(c *fiber.Ctx) error {
	familyID, ok := c.Locals("family_id").(uuid.UUID)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Family not found in session"})
	}

	var req struct {
		Name      string `json:"name"`
		AvatarURL string `json:"avatar_url"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request"})
	}

	child := domain.Child{
		ID:        uuid.New(),
		FamilyID:  familyID,
		Name:      req.Name,
		AvatarURL: req.AvatarURL,
	}

	if err := h.repo.CreateChild(c.Context(), &child); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(fiber.StatusCreated).JSON(child)
}

// DeleteChild removes a child profile and cascades to unpair devices and delete records
func (h *DeviceHandler) DeleteChild(c *fiber.Ctx) error {
	childIDStr := c.Params("id")
	childID, err := uuid.Parse(childIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid child ID"})
	}

	familyID, ok := c.Locals("family_id").(uuid.UUID)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Family not found in session"})
	}

	// Verify child belongs to family
	children, err := h.repo.GetChildrenByFamily(c.Context(), familyID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Database error"})
	}
	var targetChild *domain.Child
	for _, ch := range children {
		if ch.ID == childID {
			targetChild = &ch
			break
		}
	}
	if targetChild == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Child not found in your family"})
	}

	// Notify any active devices of this child to unpair and reset
	devices, _ := h.repo.GetDevicesByFamilyID(c.Context(), familyID)
	for _, dev := range devices {
		if dev.ChildID != nil && *dev.ChildID == childID {
			if h.wsHub != nil {
				_ = h.wsHub.SendDirectMessageToKid(dev.ID.String(), domain.TypeUnpairAndReset, map[string]interface{}{
					"action": "UNPAIR_AND_RESET",
					"reason": "child_deleted_by_parent",
				})
				h.wsHub.DisconnectKid(dev.ID.String())
			}
		}
	}

	if err := h.repo.DeleteChildCompletely(c.Context(), childID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to delete child: " + err.Error()})
	}

	return c.JSON(fiber.Map{"message": "Child and associated data deleted successfully"})
}

// GeneratePairingCode produces 6-digit code for linking
func (h *DeviceHandler) GeneratePairingCode(c *fiber.Ctx) error {
	familyID, ok := c.Locals("family_id").(uuid.UUID)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Family not found in session"})
	}

	childIDStr := c.Params("child_id")
	childID, err := uuid.Parse(childIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid child_id"})
	}

	pc, err := h.pairingService.GeneratePairingCode(c.Context(), familyID, childID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(pc)
}

// PairDevice registers the Android Kid device
func (h *DeviceHandler) PairDevice(c *fiber.Ctx) error {
	var req service.PairDeviceRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	resp, err := h.pairingService.PairKidDevice(c.Context(), req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(fiber.StatusCreated).JSON(resp)
}

// SendCommand dispatches an immediate remote command (LOCK, UNLOCK, ALARM, etc.)
func (h *DeviceHandler) SendCommand(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req struct {
		Action string                 `json:"action"` // LOCK_DEVICE, UNLOCK_DEVICE, PLAY_ALARM, SCREENSHOT
		Params map[string]interface{} `json:"params"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid command format"})
	}

	// Feature Gating for specific commands
	checkFeature := func(reqFeat string, featNameArabic string) error {
		if sub, ok := c.Locals("subscription").(*domain.Subscription); ok {
			tierStr := string(sub.Tier)
			if strings.EqualFold(tierStr, "family_unlimited") || strings.EqualFold(tierStr, "unlimited") {
				return nil
			}
			plans, _ := h.repo.GetAllPlans(c.Context())
			hasFeat := false
			for _, p := range plans {
				if strings.EqualFold(p.Tier, tierStr) || strings.EqualFold(p.ID, tierStr) {
					var feats []string
					if err := json.Unmarshal([]byte(p.Features), &feats); err == nil {
						for _, f := range feats {
							if strings.EqualFold(f, reqFeat) {
								hasFeat = true
								break
							}
						}
					}
					break
				}
			}
			if !hasFeat {
				return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
					"error":   "feature_not_supported",
					"message": fmt.Sprintf("ميزة %s غير متاحة في باقتك الحالية. يرجى ترقية الباقة لتفعيلها.", featNameArabic),
					"feature": reqFeat,
				})
			}
		}
		return nil
	}

	if req.Action == "TAKE_SCREENSHOT" || req.Action == "SCREENSHOT" {
		if err := checkFeature("silent_screenshot", "لقطة الشاشة الصامتة"); err != nil {
			return err
		}
	} else if req.Action == "HIDE_APP_ICON" || req.Action == "SHOW_APP_ICON" {
		if err := checkFeature("stealth_mode", "إخفاء ووضع التخفي للتطبيق"); err != nil {
			return err
		}
	} else if req.Action == "SET_ANTI_UNINSTALL" {
		if err := checkFeature("anti_uninstall", "حماية منع إزالة التطبيق"); err != nil {
			return err
		}
	} else if req.Action == "SET_BLOCK_SETTINGS" {
		if err := checkFeature("settings_protection", "حظر الوصول إلى إعدادات الهاتف"); err != nil {
			return err
		}
	}

	if req.Action == "PAUSE_MONITORING" {
		_ = h.repo.SetDeviceMonitoringPaused(c.Context(), deviceID, true)
	} else if req.Action == "RESUME_MONITORING" {
		_ = h.repo.SetDeviceMonitoringPaused(c.Context(), deviceID, false)
	}

	cmd, err := h.deviceService.QueueCommand(c.Context(), deviceID, req.Action, req.Params)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	// Immediate real-time push over WebSocket if kid device is connected
	if h.wsHub != nil {
		_ = h.wsHub.SendCommandToKid(deviceIDStr, cmd, req.Action, req.Params)
		if req.Action == "PAUSE_MONITORING" || req.Action == "RESUME_MONITORING" {
			device, err := h.repo.GetDeviceByID(c.Context(), deviceID)
			if err == nil && device != nil {
				isPaused := req.Action == "PAUSE_MONITORING"
				payloadBytes, _ := json.Marshal(map[string]interface{}{
					"device_id":            deviceID.String(),
					"is_monitoring_paused": isPaused,
				})
				h.wsHub.Lock()
				h.wsHub.broadcastToFamilyParents(device.FamilyID.String(), domain.WSMessage{
					Type:      "MONITORING_STATUS_CHANGED",
					From:      "server",
					FamilyID:  device.FamilyID.String(),
					Timestamp: time.Now().UnixMilli(),
					Payload:   payloadBytes,
				})
				h.wsHub.Unlock()
			}
		}
	}

	return c.Status(fiber.StatusAccepted).JSON(cmd)
}

// GetScreenTimeRule fetches screen time rules
func (h *DeviceHandler) GetScreenTimeRule(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	rule, err := h.repo.GetScreenTimeRule(c.Context(), deviceID)
	if err != nil {
		return c.JSON(domain.ScreenTimeRule{
			DeviceID:          deviceID,
			DailyLimitMinutes: 120,
			DowntimeStart:     "21:00",
			DowntimeEnd:       "07:00",
			IsActive:          true,
		})
	}
	return c.JSON(rule)
}

// SaveScreenTimeRule saves rules and notifies kid
func (h *DeviceHandler) SaveScreenTimeRule(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req domain.ScreenTimeRule
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid body"})
	}
	req.DeviceID = deviceID

	if err := h.repo.UpsertScreenTimeRule(c.Context(), &req); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	ruleBytes, _ := json.Marshal(req)
	h.wsHub.Lock()
	if kidClient, ok := h.wsHub.kids[deviceID.String()]; ok {
		wsMsg := domain.WSMessage{
			Type:      domain.TypeScreenTimeRuleSync,
			To:        deviceID.String(),
			Timestamp: time.Now().UnixMilli(),
			Payload:   ruleBytes,
		}
		raw, _ := json.Marshal(wsMsg)
		select {
		case kidClient.Send <- raw:
		default:
		}
	}
	h.wsHub.Unlock()

	return c.JSON(req)
}

// GetContacts fetches contacts of kid device
func (h *DeviceHandler) GetContacts(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	contacts, err := h.repo.GetKidContacts(c.Context(), deviceID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(contacts)
}

// GetSMS fetches sms messages of kid device
func (h *DeviceHandler) GetSMS(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	messages, err := h.repo.GetKidSMS(c.Context(), deviceID, 100)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(messages)
}

// GetFiles fetches files / media of kid device
func (h *DeviceHandler) GetFiles(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	files, err := h.repo.GetKidFiles(c.Context(), deviceID, 100)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(files)
}

// GetCalls fetches call logs of kid device
func (h *DeviceHandler) GetCalls(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	calls, err := h.repo.GetKidCallLogs(c.Context(), deviceID, 100)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(calls)
}

// GetRiskAlerts fetches AI risk alerts of kid device
func (h *DeviceHandler) GetRiskAlerts(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	alerts, err := h.repo.GetRiskAlerts(c.Context(), deviceID, 50)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	if alerts == nil {
		alerts = []domain.RiskAlert{}
	}
	return c.JSON(alerts)
}

// MarkRiskAlertSafe marks an alert as safe and synchronizes the pattern whitelist to the child device
func (h *DeviceHandler) MarkRiskAlertSafe(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	alertIDStr := c.Params("alertId")
	alertID, err := strconv.ParseInt(alertIDStr, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid alert ID"})
	}

	alert, err := h.repo.MarkRiskAlertSafe(c.Context(), alertID, deviceID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	// Fetch all safe patterns for this device to push to kid device
	rules, err := h.repo.GetSafeRules(c.Context(), deviceID)
	if err == nil {
		patterns := make([]string, 0, len(rules))
		for _, r := range rules {
			patterns = append(patterns, r.Pattern)
		}
		if h.wsHub != nil {
			h.wsHub.SyncSafePatternsToKid(deviceID, patterns)

			// Also notify parents in the family that this alert was marked safe
			dev, _ := h.repo.GetDeviceByID(c.Context(), deviceID)
			if dev != nil {
				updatePayload, _ := json.Marshal(fiber.Map{
					"alert_id":  alertID,
					"device_id": deviceID.String(),
					"is_safe":   true,
					"snippet":   alert.Snippet,
				})
				h.wsHub.BroadcastToFamily(dev.FamilyID.String(), domain.WSMessage{
					Type:      domain.TypeRiskAlertSafeUpdated,
					From:      deviceID.String(),
					FamilyID:  dev.FamilyID.String(),
					Timestamp: time.Now().UnixMilli(),
					Payload:   updatePayload,
				})
			}
		}
	}

	return c.JSON(fiber.Map{
		"success": true,
		"alert":   alert,
		"message": "تم تصنيف الإنذار كآمن ولن يتم الإشعار بشأنه مجدداً",
	})
}

// GetSafeRiskPatterns returns whitelisted safe patterns for a device
func (h *DeviceHandler) GetSafeRiskPatterns(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	rules, err := h.repo.GetSafeRules(c.Context(), deviceID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	patterns := make([]string, 0, len(rules))
	for _, r := range rules {
		patterns = append(patterns, r.Pattern)
	}

	return c.JSON(fiber.Map{
		"patterns": patterns,
		"rules":    rules,
	})
}

// SyncOfflineData processes batch offline data (locations, calls, risk alerts) sent by kids-agent WorkManager
func (h *DeviceHandler) SyncOfflineData(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req domain.OfflineSyncRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid sync payload"})
	}

	ctx := c.Context()
	syncedLocations := 0
	syncedCalls := 0
	syncedRisks := 0

	// 1. Process batch locations
	if len(req.Locations) > 0 && h.locationService != nil {
		for _, locPayload := range req.Locations {
			_, events, err := h.locationService.RecordLocation(ctx, deviceID, locPayload)
			if err == nil {
				syncedLocations++
				if len(events) > 0 && h.wsHub != nil {
					dev, devErr := h.repo.GetDeviceByID(ctx, deviceID)
					if devErr == nil && dev != nil {
						for _, ev := range events {
							alertBytes, _ := json.Marshal(ev)
							alertMsg := domain.WSMessage{
								Type:      "GEOFENCE_ALERT",
								From:      deviceID.String(),
								FamilyID:  dev.FamilyID.String(),
								Timestamp: time.Now().UnixMilli(),
								Payload:   alertBytes,
							}
							h.wsHub.Lock()
							h.wsHub.broadcastToFamilyParents(dev.FamilyID.String(), alertMsg)
							h.wsHub.Unlock()
						}
					}
				}
			}
		}
	}

	// 2. Process batch call logs
	if len(req.Calls) > 0 {
		err := h.repo.SaveKidCallLogs(ctx, deviceID, req.Calls)
		if err == nil {
			syncedCalls = len(req.Calls)
		}
	}

	// 3. Process batch risk alerts
	if len(req.RiskAlerts) > 0 {
		dev, _ := h.repo.GetDeviceByID(ctx, deviceID)
		for _, alert := range req.RiskAlerts {
			alert.DeviceID = deviceID
			if err := h.repo.SaveRiskAlert(ctx, &alert); err == nil {
				syncedRisks++
				if h.wsHub != nil && dev != nil {
					alertBytes, _ := json.Marshal(alert)
					alertMsg := domain.WSMessage{
						Type:      domain.TypeRiskAlert,
						From:      deviceID.String(),
						FamilyID:  dev.FamilyID.String(),
						Timestamp: alert.Timestamp,
						Payload:   alertBytes,
					}
					h.wsHub.Lock()
					h.wsHub.broadcastToFamilyParents(dev.FamilyID.String(), alertMsg)
					h.wsHub.Unlock()
				}
			}
		}
	}

	return c.JSON(domain.OfflineSyncResponse{
		Success:         true,
		SyncedLocations: syncedLocations,
		SyncedCalls:     syncedCalls,
		SyncedRisks:     syncedRisks,
	})
}

// GetMySubscription returns detailed subscription and plan information for the authenticated parent
func (h *DeviceHandler) GetMySubscription(c *fiber.Ctx) error {
	familyID, ok := c.Locals("family_id").(uuid.UUID)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Family not found in session"})
	}

	sub, err := h.repo.GetSubscriptionByFamilyID(c.Context(), familyID)
	if err != nil || sub == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error":   "subscription_not_found",
			"message": "لا يوجد اشتراك مسجل لهذه العائلة",
		})
	}

	devices, _ := h.repo.GetDevicesByFamilyID(c.Context(), familyID)
	usedDevices := len(devices)

	isExpired := sub.ExpiresAt != nil && time.Now().After(*sub.ExpiresAt)
	isActive := sub.IsActive && !isExpired
	status := "active"
	if isExpired {
		status = "expired"
	} else if !sub.IsActive {
		status = "suspended"
	}

	// Find plan details
	tierStr := string(sub.Tier)
	planName := tierStr
	features := []string{}
	plans, _ := h.repo.GetAllPlans(c.Context())
	for _, p := range plans {
		if strings.EqualFold(p.Tier, tierStr) || strings.EqualFold(p.ID, tierStr) {
			planName = p.Name
			_ = json.Unmarshal([]byte(p.Features), &features)
			break
		}
	}

	return c.JSON(fiber.Map{
		"subscription_id": sub.ID,
		"family_id":       sub.FamilyID,
		"tier":            tierStr,
		"plan_name":       planName,
		"status":          status,
		"is_active":       isActive,
		"is_expired":      isExpired,
		"max_devices":     sub.MaxDevices,
		"used_devices":    usedDevices,
		"devices_left":    sub.MaxDevices - usedDevices,
		"expires_at":      sub.ExpiresAt,
		"features":        features,
	})
}

// GetDeviceAgentStatus returns device agent operational status (e.g. is_monitoring_paused)
func (h *DeviceHandler) GetDeviceAgentStatus(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	dev, err := h.repo.GetDeviceByID(c.Context(), deviceID)
	if err != nil || dev == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Device not found"})
	}

	return c.JSON(fiber.Map{
		"device_id":            dev.ID,
		"is_monitoring_paused": dev.IsMonitoringPaused,
	})
}

// DeleteDevice completely wipes device records and dispatches UNPAIR_AND_RESET to agent
func (h *DeviceHandler) DeleteDevice(c *fiber.Ctx) error {
	familyID, ok := c.Locals("family_id").(uuid.UUID)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Family not found in session"})
	}

	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	dev, err := h.repo.GetDeviceByID(c.Context(), deviceID)
	if err != nil || dev == nil || dev.FamilyID != familyID {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "الجهاز غير موجود أو لا ينتمي لهذه العائلة"})
	}

	// 1. Notify the agent device over WebSocket to wipe all restrictions and unpair
	if h.wsHub != nil {
		h.wsHub.SendDirectMessageToKid(deviceID.String(), domain.TypeUnpairAndReset, map[string]interface{}{
			"action":    "UNPAIR_AND_RESET",
			"reason":    "تم حذف الجهاز وإلغاء الاقتران بواسطة ولي الأمر",
			"timestamp": time.Now().UnixMilli(),
		})
	}

	// 2. Complete database wipe of device and all associated data
	if err := h.repo.DeleteDeviceCompletely(c.Context(), deviceID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": fmt.Sprintf("فشل حذف الجهاز: %v", err)})
	}

	// 3. Disconnect WebSocket client
	if h.wsHub != nil {
		h.wsHub.DisconnectKid(deviceID.String())
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "تم حذف الجهاز وإلغاء كافة القيود والبيانات بالكامل",
	})
}
