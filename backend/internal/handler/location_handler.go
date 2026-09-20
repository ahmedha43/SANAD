package handler

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
	"github.com/parental-control/backend/internal/service"
)

type LocationHandler struct {
	repo            *repository.Repository
	locationService *service.LocationService
}

func NewLocationHandler(repo *repository.Repository, locationService *service.LocationService) *LocationHandler {
	return &LocationHandler{repo: repo, locationService: locationService}
}

// PostLocation from Kid device via REST fallback if WebSocket disconnected
func (h *LocationHandler) PostLocation(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	var payload domain.LocationPayload
	if err := c.BodyParser(&payload); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid payload"})
	}

	loc, events, err := h.locationService.RecordLocation(c.Context(), deviceID, payload)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"location": loc,
		"events":   events,
	})
}

// GetLatestLocation gets current coordinate of device
func (h *LocationHandler) GetLatestLocation(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	loc, err := h.repo.GetLatestLocation(c.Context(), deviceID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "No location records found"})
	}

	return c.JSON(loc)
}

// GetLocationHistory returns timeline trail for trip replay
func (h *LocationHandler) GetLocationHistory(c *fiber.Ctx) error {
	deviceIDStr := c.Params("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid device ID"})
	}

	// Query params: hours (default 24)
	hoursStr := c.Query("hours", "24")
	hours, _ := strconv.Atoi(hoursStr)
	since := time.Now().Add(-time.Duration(hours) * time.Hour)

	logs, err := h.repo.GetLocationHistory(c.Context(), deviceID, since)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(logs)
}

// CreateGeofence adds a safe zone
func (h *LocationHandler) CreateGeofence(c *fiber.Ctx) error {
	var req struct {
		ChildID      uuid.UUID `json:"child_id"`
		Name         string    `json:"name"`
		Latitude     float64   `json:"latitude"`
		Longitude    float64   `json:"longitude"`
		Radius       int       `json:"radius"`
		RadiusMeters int       `json:"radius_meters"`
		TriggerType  string    `json:"trigger_type"`
		AlertOnEntry *bool     `json:"alert_on_entry"`
		AlertOnExit  *bool     `json:"alert_on_exit"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid geofence data"})
	}

	rad := req.RadiusMeters
	if rad <= 0 && req.Radius > 0 {
		rad = req.Radius
	}
	if rad <= 0 {
		rad = 300
	}

	onEntry := true
	onExit := true
	if req.AlertOnEntry != nil {
		onEntry = *req.AlertOnEntry
	}
	if req.AlertOnExit != nil {
		onExit = *req.AlertOnExit
	}
	if req.TriggerType == "enter" {
		onEntry = true
		onExit = false
	} else if req.TriggerType == "exit" {
		onEntry = false
		onExit = true
	}

	gf := domain.Geofence{
		ID:           uuid.New(),
		ChildID:      req.ChildID,
		Name:         req.Name,
		Latitude:     req.Latitude,
		Longitude:    req.Longitude,
		RadiusMeters: rad,
		AlertOnEntry: onEntry,
		AlertOnExit:  onExit,
		IsActive:     true,
		CreatedAt:    time.Now(),
	}

	if err := h.repo.CreateGeofence(c.Context(), &gf); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(fiber.StatusCreated).JSON(gf)
}

// GetGeofences returns active geofences for a child
func (h *LocationHandler) GetGeofences(c *fiber.Ctx) error {
	childIDStr := c.Params("child_id")
	childID, err := uuid.Parse(childIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid child ID"})
	}

	gfs, err := h.repo.GetGeofencesByChild(c.Context(), childID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	if gfs == nil {
		gfs = []domain.Geofence{}
	}

	return c.JSON(gfs)
}

// DeleteGeofence deletes a safe zone
func (h *LocationHandler) DeleteGeofence(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid geofence ID"})
	}

	if err := h.repo.DeleteGeofence(c.Context(), id); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"status": "deleted"})
}

// GetGeofenceEvents returns historical entry/exit breach events for a child
func (h *LocationHandler) GetGeofenceEvents(c *fiber.Ctx) error {
	childIDStr := c.Params("child_id")
	childID, err := uuid.Parse(childIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid child ID"})
	}

	events, err := h.repo.GetGeofenceEventsByChild(c.Context(), childID, 50)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}

	if events == nil {
		events = []domain.GeofenceEvent{}
	}

	return c.JSON(events)
}

