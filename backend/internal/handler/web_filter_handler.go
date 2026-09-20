package handler

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
)

type WebFilterHandler struct {
	repo  *repository.Repository
	wsHub *WSHub
}

func NewWebFilterHandler(repo *repository.Repository, wsHub *WSHub) *WebFilterHandler {
	return &WebFilterHandler{repo: repo, wsHub: wsHub}
}

// broadcastWebFilterSync sends active rules & status to kid's device and notifies family parents
func (h *WebFilterHandler) broadcastWebFilterSync(ctx context.Context, deviceID uuid.UUID) {
	device, err := h.repo.GetDeviceByID(ctx, deviceID)
	if err != nil || device == nil {
		return
	}

	rules, err := h.repo.GetActiveWebFilterRules(ctx, deviceID)
	if err != nil {
		return
	}

	keywords := make([]string, 0)
	domains := make([]string, 0)

	for _, r := range rules {
		clean := strings.TrimSpace(r.Pattern)
		if clean == "" {
			continue
		}
		if r.RuleType == "keyword" {
			keywords = append(keywords, strings.ToLower(clean))
		} else if r.RuleType == "domain" {
			clean = strings.TrimPrefix(clean, "https://")
			clean = strings.TrimPrefix(clean, "http://")
			clean = strings.TrimPrefix(clean, "www.")
			clean = strings.TrimRight(clean, "/")
			domains = append(domains, strings.ToLower(clean))
		}
	}

	effectiveEnabled := device.IsWebFilterEnabled && !device.IsMonitoringPaused

	payload := map[string]interface{}{
		"is_web_filter_enabled": effectiveEnabled,
		"keywords":              keywords,
		"domains":               domains,
	}

	// 1. Send command to Kid device via WebSocket
	cmd := &domain.DeviceCommand{
		ID:          uuid.New(),
		DeviceID:    deviceID,
		CommandType: "WEB_FILTER_SYNC",
		Status:      domain.CommandSent,
		CreatedAt:   time.Now(),
	}
	_ = h.wsHub.SendCommandToKid(deviceID.String(), cmd, "WEB_FILTER_SYNC", payload)

	// 2. Broadcast update to parents
	payloadBytes, _ := json.Marshal(payload)
	h.wsHub.Lock()
	h.wsHub.broadcastToFamilyParents(device.FamilyID.String(), domain.WSMessage{
		Type:      "WEB_FILTER_UPDATED",
		From:      "server",
		DeviceID:  deviceID.String(),
		FamilyID:  device.FamilyID.String(),
		Timestamp: time.Now().UnixMilli(),
		Payload:   payloadBytes,
	})
	h.wsHub.Unlock()
}

// GetRules lists all rules and current engine status
func (h *WebFilterHandler) GetRules(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	device, err := h.repo.GetDeviceByID(c.Context(), deviceID)
	if err != nil || device == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Device not found"})
	}

	rules, err := h.repo.GetWebFilterRules(c.Context(), deviceID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{
		"device_id":             deviceID,
		"is_web_filter_enabled": device.IsWebFilterEnabled,
		"is_monitoring_paused":  device.IsMonitoringPaused,
		"rules":                 rules,
		"total":                 len(rules),
	})
}

// CreateRule adds a keyword or URL domain rule
func (h *WebFilterHandler) CreateRule(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req struct {
		RuleType string `json:"rule_type"` // 'keyword' or 'domain'
		Pattern  string `json:"pattern"`
		Category string `json:"category"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	req.Pattern = strings.TrimSpace(req.Pattern)
	if req.Pattern == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Pattern cannot be empty"})
	}

	if req.RuleType != "keyword" && req.RuleType != "domain" {
		req.RuleType = "keyword"
	}
	if req.Category == "" {
		req.Category = "custom"
	}

	rule := domain.WebFilterRule{
		DeviceID:  deviceID,
		RuleType:  req.RuleType,
		Pattern:   req.Pattern,
		Category:  req.Category,
		IsActive:  true,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if err := h.repo.CreateWebFilterRule(c.Context(), &rule); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	h.broadcastWebFilterSync(c.Context(), deviceID)

	return c.Status(fiber.StatusCreated).JSON(rule)
}

// ToggleEngine turns the entire web filter engine on or off for the device
func (h *WebFilterHandler) ToggleEngine(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req struct {
		Enabled bool `json:"enabled"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	if err := h.repo.SetDeviceWebFilterEnabled(c.Context(), deviceID, req.Enabled); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	h.broadcastWebFilterSync(c.Context(), deviceID)

	return c.JSON(fiber.Map{
		"device_id":             deviceID,
		"is_web_filter_enabled": req.Enabled,
		"updated":               true,
	})
}

// ToggleAll turns all rules on or off
func (h *WebFilterHandler) ToggleAll(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var req struct {
		Enabled bool `json:"enabled"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	if err := h.repo.ToggleAllWebFilterRules(c.Context(), deviceID, req.Enabled); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	h.broadcastWebFilterSync(c.Context(), deviceID)

	return c.JSON(fiber.Map{
		"device_id":  deviceID,
		"all_active": req.Enabled,
		"updated":    true,
	})
}

// ToggleRule toggles a single rule
func (h *WebFilterHandler) ToggleRule(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	ruleIDStr := c.Params("rule_id")
	ruleID, err := uuid.Parse(ruleIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid rule ID"})
	}

	var req struct {
		IsActive bool `json:"is_active"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	if err := h.repo.ToggleWebFilterRule(c.Context(), ruleID, req.IsActive); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	h.broadcastWebFilterSync(c.Context(), deviceID)

	return c.JSON(fiber.Map{
		"rule_id":   ruleID,
		"is_active": req.IsActive,
		"updated":   true,
	})
}

// DeleteRule removes a rule
func (h *WebFilterHandler) DeleteRule(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	ruleIDStr := c.Params("rule_id")
	ruleID, err := uuid.Parse(ruleIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid rule ID"})
	}

	if err := h.repo.DeleteWebFilterRule(c.Context(), ruleID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	h.broadcastWebFilterSync(c.Context(), deviceID)

	return c.JSON(fiber.Map{
		"deleted_rule_id": ruleID,
		"success":         true,
	})
}

// SeedDefaults populates standard intelligent lists for adult, gambling, drugs, violence, bypass
func (h *WebFilterHandler) SeedDefaults(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	if err := h.repo.SeedDefaultWebFilterRules(c.Context(), deviceID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	h.broadcastWebFilterSync(c.Context(), deviceID)

	rules, _ := h.repo.GetWebFilterRules(c.Context(), deviceID)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Default web filter rules seeded successfully",
		"total":   len(rules),
	})
}

// GetAgentWebFilter provides the kid's agent with active web filter rules
func (h *WebFilterHandler) GetAgentWebFilter(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	device, err := h.repo.GetDeviceByID(c.Context(), deviceID)
	if err != nil || device == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Device not found"})
	}

	rules, err := h.repo.GetActiveWebFilterRules(c.Context(), deviceID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	keywords := make([]string, 0)
	domains := make([]string, 0)

	for _, r := range rules {
		clean := strings.TrimSpace(r.Pattern)
		if clean == "" {
			continue
		}
		if r.RuleType == "keyword" {
			keywords = append(keywords, strings.ToLower(clean))
		} else if r.RuleType == "domain" {
			clean = strings.TrimPrefix(clean, "https://")
			clean = strings.TrimPrefix(clean, "http://")
			clean = strings.TrimPrefix(clean, "www.")
			clean = strings.TrimRight(clean, "/")
			domains = append(domains, strings.ToLower(clean))
		}
	}

	effectiveEnabled := device.IsWebFilterEnabled && !device.IsMonitoringPaused

	return c.JSON(fiber.Map{
		"is_web_filter_enabled": effectiveEnabled,
		"keywords":              keywords,
		"domains":               domains,
	})
}
