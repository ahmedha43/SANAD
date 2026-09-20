package handler

import (
	"encoding/json"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
)

type BrowserHistoryHandler struct {
	repo  *repository.Repository
	wsHub *WSHub
}

func NewBrowserHistoryHandler(repo *repository.Repository, wsHub *WSHub) *BrowserHistoryHandler {
	return &BrowserHistoryHandler{repo: repo, wsHub: wsHub}
}

// PostBrowserHistory receives batch browsing history from agents (Windows or Android)
func (h *BrowserHistoryHandler) PostBrowserHistory(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	device, err := h.repo.GetDeviceByID(c.Context(), deviceID)
	if err != nil || device == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Device not found"})
	}

	// Verify pairing secret
	secret := c.Get("X-Device-Secret")
	if secret == "" || secret != device.PairingSecret {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized device secret"})
	}

	var req domain.BrowserHistoryBatchRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	if len(req.Items) == 0 {
		return c.JSON(fiber.Map{"success": true, "inserted": 0})
	}

	inserted, err := h.repo.SaveBrowserHistoryBatch(c.Context(), deviceID, req.Items)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to save history"})
	}

	// Notify parents via WebSocket
	if inserted > 0 && h.wsHub != nil {
		payloadBytes, _ := json.Marshal(map[string]interface{}{
			"device_id": deviceID.String(),
			"inserted":  inserted,
		})
		h.wsHub.Lock()
		h.wsHub.broadcastToFamilyParents(device.FamilyID.String(), domain.WSMessage{
			Type:      "BROWSER_HISTORY_SYNCED",
			From:      "server",
			DeviceID:  deviceID.String(),
			FamilyID:  device.FamilyID.String(),
			Timestamp: time.Now().UnixMilli(),
			Payload:   payloadBytes,
		})
		h.wsHub.Unlock()
	}

	return c.JSON(fiber.Map{
		"success":  true,
		"inserted": inserted,
	})
}

// GetBrowserHistory returns paginated history records with filters for parents
func (h *BrowserHistoryHandler) GetBrowserHistory(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	limit, _ := strconv.Atoi(c.Query("limit", "100"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))
	filter := strings.ToLower(c.Query("filter", "all"))
	search := c.Query("search", "")

	records, total, err := h.repo.GetBrowserHistory(c.Context(), deviceID, limit, offset, filter, search)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to fetch history"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"total":   total,
		"limit":   limit,
		"offset":  offset,
		"history": records,
	})
}

// GetBrowserHistoryStats returns top search terms, top domains, and count stats
func (h *BrowserHistoryHandler) GetBrowserHistoryStats(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	stats, err := h.repo.GetBrowserHistoryStats(c.Context(), deviceID)
	if err != nil {
		stats = map[string]interface{}{"today_visits": 0, "total_searches": 0, "total_blocked": 0}
	}

	topSearches, err := h.repo.GetTopSearchQueries(c.Context(), deviceID, 12)
	if err != nil {
		topSearches = []map[string]interface{}{}
	}

	topDomains, err := h.repo.GetTopVisitedDomains(c.Context(), deviceID, 8)
	if err != nil {
		topDomains = []map[string]interface{}{}
	}

	return c.JSON(fiber.Map{
		"success":      true,
		"stats":        stats,
		"top_searches": topSearches,
		"top_domains":  topDomains,
	})
}

// ClearBrowserHistory wipes history records for a device
func (h *BrowserHistoryHandler) ClearBrowserHistory(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	if err := h.repo.ClearBrowserHistory(c.Context(), deviceID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to clear history"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Browser history cleared successfully",
	})
}

// QuickBlockDomain blocks a domain directly from the history view in 1 click
func (h *BrowserHistoryHandler) QuickBlockDomain(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req struct {
		Domain string `json:"domain"`
	}
	if err := c.BodyParser(&req); err != nil || strings.TrimSpace(req.Domain) == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid domain"})
	}

	cleanDomain := strings.ToLower(strings.TrimSpace(req.Domain))
	cleanDomain = strings.TrimPrefix(cleanDomain, "https://")
	cleanDomain = strings.TrimPrefix(cleanDomain, "http://")
	cleanDomain = strings.TrimPrefix(cleanDomain, "www.")
	cleanDomain = strings.TrimRight(cleanDomain, "/")

	rule := &domain.WebFilterRule{
		DeviceID: deviceID,
		RuleType: "domain",
		Pattern:  cleanDomain,
		Category: "custom",
		IsActive: true,
	}

	if err := h.repo.CreateWebFilterRule(c.Context(), rule); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to create filter rule"})
	}

	// Mark all matching history items as blocked
	_ = h.repo.GetDB().WithContext(c.Context()).
		Model(&domain.BrowserHistory{}).
		Where("device_id = ? AND (domain = ? OR url LIKE ?)", deviceID, cleanDomain, "%"+cleanDomain+"%").
		Update("is_blocked", true).Error

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Domain blocked successfully and synchronized",
		"domain":  cleanDomain,
	})
}
