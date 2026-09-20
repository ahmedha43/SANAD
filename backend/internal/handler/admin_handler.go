package handler

import (
	"fmt"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
)

type AdminHandler struct {
	repo  *repository.Repository
	wsHub *WSHub
}

func NewAdminHandler(repo *repository.Repository, wsHub *WSHub) *AdminHandler {
	return &AdminHandler{
		repo:  repo,
		wsHub: wsHub,
	}
}

// GetOverview returns dashboard summary cards, recent devices, and recent audit logs
func (h *AdminHandler) GetOverview(c *fiber.Ctx) error {
	stats, err := h.repo.GetAdminStats(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	onlineCount := int64(h.wsHub.GetOnlineDeviceCount())
	// If WS hub has 0 (e.g. simulated devices), count devices where status = 'online'
	allDevices, _ := h.repo.GetAllDevices(c.Context())
	var dbOnline int64 = 0
	for _, d := range allDevices {
		if d.Status == "online" {
			dbOnline++
		}
	}
	if onlineCount < dbOnline {
		onlineCount = dbOnline
	}
	stats["online_devices"] = onlineCount

	// Recent 6 devices
	recentDevices := allDevices
	if len(recentDevices) > 6 {
		recentDevices = recentDevices[:6]
	}

	logs, _ := h.repo.GetAuditLogs(c.Context(), 10)

	return c.JSON(fiber.Map{
		"stats":          stats,
		"recent_devices": recentDevices,
		"recent_logs":    logs,
		"status":         "operational",
	})
}

// GetUsers returns all registered parents and family trees
func (h *AdminHandler) GetUsers(c *fiber.Ctx) error {
	users, err := h.repo.GetAllUsers(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(users)
}

// GetDevices returns all kids devices with child details
func (h *AdminHandler) GetDevices(c *fiber.Ctx) error {
	devices, err := h.repo.GetAllDevices(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(devices)
}

// GetSubscriptions returns all family subscriptions and licensing tiers
func (h *AdminHandler) GetSubscriptions(c *fiber.Ctx) error {
	subs, err := h.repo.GetAllSubscriptions(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(subs)
}

// GetLogs returns security audit logs
func (h *AdminHandler) GetLogs(c *fiber.Ctx) error {
	logs, err := h.repo.GetAuditLogs(c.Context(), 50)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(logs)
}

// GetPlans returns all available subscription packages
func (h *AdminHandler) GetPlans(c *fiber.Ctx) error {
	plans, err := h.repo.GetAllPlans(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(plans)
}

// CreatePlan creates a new subscription package
func (h *AdminHandler) CreatePlan(c *fiber.Ctx) error {
	var plan domain.SubscriptionPlan
	if err := c.BodyParser(&plan); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid plan data"})
	}
	if plan.ID == "" {
		plan.ID = fmt.Sprintf("plan_%d", time.Now().Unix())
	}
	plan.CreatedAt = time.Now()
	plan.UpdatedAt = time.Now()

	if err := h.repo.SavePlan(c.Context(), &plan); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	h.repo.LogAuditEvent(c.Context(), "PLAN_CREATED", plan.ID, fmt.Sprintf("Name: %s | Price: %.2f", plan.Name, plan.Price), nil, c.IP())
	return c.Status(fiber.StatusCreated).JSON(plan)
}

// UpdatePlan updates an existing subscription package
func (h *AdminHandler) UpdatePlan(c *fiber.Ctx) error {
	id := c.Params("id")
	plan, err := h.repo.GetPlanByID(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Plan not found"})
	}

	var req domain.SubscriptionPlan
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid plan data"})
	}

	if req.Name != "" { plan.Name = req.Name }
	if req.Tier != "" { plan.Tier = req.Tier }
	plan.Price = req.Price
	if req.Currency != "" { plan.Currency = req.Currency }
	if req.BillingCycle != "" { plan.BillingCycle = req.BillingCycle }
	if req.DurationDays > 0 { plan.DurationDays = req.DurationDays }
	if req.MaxDevices > 0 { plan.MaxDevices = req.MaxDevices }
	if req.Features != "" { plan.Features = req.Features }
	plan.IsActive = req.IsActive
	plan.UpdatedAt = time.Now()

	if err := h.repo.SavePlan(c.Context(), plan); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	h.repo.LogAuditEvent(c.Context(), "PLAN_UPDATED", plan.ID, fmt.Sprintf("Price: %.2f | MaxDevices: %d", plan.Price, plan.MaxDevices), nil, c.IP())
	return c.JSON(plan)
}

// DeletePlan deletes a subscription package
func (h *AdminHandler) DeletePlan(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := h.repo.DeletePlan(c.Context(), id); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	h.repo.LogAuditEvent(c.Context(), "PLAN_DELETED", id, "Plan removed", nil, c.IP())
	return c.JSON(fiber.Map{"success": true})
}

// UpdateSubscription modifies a family subscription (tier, max devices, expiry, active status)
func (h *AdminHandler) UpdateSubscription(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid subscription ID"})
	}

	sub, err := h.repo.GetSubscriptionByID(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Subscription not found"})
	}

	var req struct {
		Tier       domain.SubscriptionTier `json:"tier"`
		MaxDevices int                     `json:"max_devices"`
		ExpiresAt  *time.Time              `json:"expires_at"`
		IsActive   *bool                   `json:"is_active"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request body"})
	}

	if req.Tier != "" {
		sub.Tier = req.Tier
	}
	if req.MaxDevices > 0 {
		sub.MaxDevices = req.MaxDevices
	}
	if req.ExpiresAt != nil {
		sub.ExpiresAt = req.ExpiresAt
	}
	if req.IsActive != nil {
		sub.IsActive = *req.IsActive
	}

	if err := h.repo.UpdateSubscription(c.Context(), sub); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	h.repo.LogAuditEvent(c.Context(), "SUBSCRIPTION_UPDATED", sub.ID.String(), fmt.Sprintf("Family: %s | Tier: %s | MaxDevices: %d", sub.FamilyID, sub.Tier, sub.MaxDevices), nil, c.IP())
	return c.JSON(sub)
}

// RenewSubscription extends a subscription by specified days (default 30)
func (h *AdminHandler) RenewSubscription(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid subscription ID"})
	}

	sub, err := h.repo.GetSubscriptionByID(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Subscription not found"})
	}

	var req struct {
		Days int `json:"days"`
	}
	_ = c.BodyParser(&req)
	days := req.Days
	if days <= 0 {
		days = 30
	}

	baseTime := time.Now()
	if sub.ExpiresAt != nil && sub.ExpiresAt.After(baseTime) {
		baseTime = *sub.ExpiresAt
	}
	newExpiry := baseTime.AddDate(0, 0, days)
	sub.ExpiresAt = &newExpiry
	sub.IsActive = true

	if err := h.repo.UpdateSubscription(c.Context(), sub); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	h.repo.LogAuditEvent(c.Context(), "SUBSCRIPTION_RENEWED", sub.ID.String(), fmt.Sprintf("Extended by %d days. New Expiry: %s", days, newExpiry.Format("2006-01-02")), nil, c.IP())
	return c.JSON(sub)
}

// ToggleSubscription suspends or reactivates a subscription
func (h *AdminHandler) ToggleSubscription(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid subscription ID"})
	}

	sub, err := h.repo.GetSubscriptionByID(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Subscription not found"})
	}

	sub.IsActive = !sub.IsActive
	if err := h.repo.UpdateSubscription(c.Context(), sub); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	action := "SUBSCRIPTION_ACTIVATED"
	if !sub.IsActive {
		action = "SUBSCRIPTION_SUSPENDED"
	}
	h.repo.LogAuditEvent(c.Context(), action, sub.ID.String(), fmt.Sprintf("IsActive: %v", sub.IsActive), nil, c.IP())
	return c.JSON(sub)
}

