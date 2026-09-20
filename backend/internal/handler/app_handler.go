package handler

import (
	"encoding/json"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
	"github.com/parental-control/backend/internal/service"
)

type AppHandler struct {
	repo          *repository.Repository
	appService    *service.AppService
	deviceService *service.DeviceService
	wsHub         *WSHub
}

func NewAppHandler(repo *repository.Repository, appService *service.AppService, deviceService *service.DeviceService, wsHub *WSHub) *AppHandler {
	return &AppHandler{repo: repo, appService: appService, deviceService: deviceService, wsHub: wsHub}
}

// SyncInstalledApps updates the inventory of apps installed on Kid device
func (h *AppHandler) SyncInstalledApps(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req struct {
		Apps []domain.DeviceApp `json:"apps"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid app payload"})
	}

	if err := h.appService.SyncApps(c.Context(), deviceID, req.Apps); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"status": "synchronized", "count": len(req.Apps)})
}

// GetDeviceApps lists apps and their block status
func (h *AppHandler) GetDeviceApps(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	apps, err := h.repo.GetDeviceApps(c.Context(), deviceID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(apps)
}

// GetBlockedApps returns list of blocked package names for a kid device
func (h *AppHandler) GetBlockedApps(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	// If device monitoring is paused, bypass app blocking
	dev, err := h.repo.GetDeviceByID(c.Context(), deviceID)
	if err == nil && dev != nil && dev.IsMonitoringPaused {
		return c.JSON([]string{})
	}

	apps, err := h.repo.GetDeviceApps(c.Context(), deviceID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	blocked := make([]string, 0)
	for _, a := range apps {
		if a.IsBlocked {
			blocked = append(blocked, a.PackageName)
		}
	}

	return c.JSON(blocked)
}

// ToggleBlock updates blocked flag for a package
func (h *AppHandler) ToggleBlock(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req struct {
		AppID       string `json:"app_id"`
		PackageName string `json:"package_name"`
		IsBlocked   bool   `json:"is_blocked"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	pkgName := req.PackageName
	if pkgName == "" && req.AppID != "" {
		appUID, parseErr := uuid.Parse(req.AppID)
		if parseErr == nil {
			apps, err := h.repo.GetDeviceApps(c.Context(), deviceID)
			if err == nil {
				for _, a := range apps {
					if a.ID == appUID {
						pkgName = a.PackageName
						break
					}
				}
			}
		}
	}

	if pkgName == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Package name or valid app ID required"})
	}

	if err := h.appService.ToggleAppBlock(c.Context(), deviceID, pkgName, req.IsBlocked); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	// Dispatch real-time WebSocket command to kid device
	action := "BLOCK_APP"
	if !req.IsBlocked {
		action = "UNBLOCK_APP"
	}
	params := map[string]interface{}{
		"package_name": pkgName,
	}

	if h.deviceService != nil {
		cmd, err := h.deviceService.QueueCommand(c.Context(), deviceID, action, params)
		if err == nil && h.wsHub != nil {
			_ = h.wsHub.SendCommandToKid(deviceID.String(), cmd, action, params)
		}
	} else if h.wsHub != nil {
		cmd := &domain.DeviceCommand{
			ID:          uuid.New(),
			DeviceID:    deviceID,
			CommandType: action,
			Status:      domain.CommandSent,
		}
		_ = h.wsHub.SendCommandToKid(deviceID.String(), cmd, action, params)
	}

	return c.JSON(fiber.Map{
		"package_name": pkgName,
		"is_blocked":   req.IsBlocked,
		"updated":      true,
	})
}

// SyncDailyUsage records screen time usage for apps
func (h *AppHandler) SyncDailyUsage(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var items []domain.AppUsageDaily
	if err := c.BodyParser(&items); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid usage data format"})
	}

	for _, item := range items {
		item.DeviceID = deviceID
		_ = h.appService.RecordDailyUsage(c.Context(), &item)
	}

	return c.JSON(fiber.Map{"status": "recorded", "count": len(items)})
}

// GetDailyUsage fetches usage metrics for a date
func (h *AppHandler) GetDailyUsage(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	dateStr := c.Query("date", time.Now().Format("2006-01-02"))
	stats, err := h.repo.GetUsageByDate(c.Context(), deviceID, dateStr)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(stats)
}

// GetNotifications returns intercepted notifications
func (h *AppHandler) GetNotifications(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	notifs, err := h.repo.GetKidNotifications(c.Context(), deviceID, 50)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(notifs)
}

// PostNotification records an intercepted notification from Kid device
func (h *AppHandler) PostNotification(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req struct {
		AppName     string `json:"app_name"`
		PackageName string `json:"package_name"`
		Title       string `json:"title"`
		Content     string `json:"content"`
		Timestamp   int64  `json:"timestamp"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid notification payload"})
	}

	receivedAt := time.Now()
	if req.Timestamp > 0 {
		receivedAt = time.UnixMilli(req.Timestamp)
	}

	if err := h.appService.SaveNotification(c.Context(), deviceID, req.AppName, req.PackageName, req.Title, req.Content, receivedAt); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	// Also broadcast via WebSocket to parents in the same family
	if h.wsHub != nil {
		device, err := h.repo.GetDeviceByID(c.Context(), deviceID)
		if err == nil && device != nil {
			payloadBytes, _ := json.Marshal(req)
			msg := domain.WSMessage{
				Type:      domain.TypeNotifForward,
				From:      deviceID.String(),
				FamilyID:  device.FamilyID.String(),
				Timestamp: time.Now().UnixMilli(),
				Payload:   payloadBytes,
			}
			h.wsHub.Lock()
			h.wsHub.broadcastToFamilyParents(device.FamilyID.String(), msg)
			h.wsHub.Unlock()
		}
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{"status": "saved"})
}
