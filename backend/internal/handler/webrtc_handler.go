package handler

import (
	"github.com/gofiber/fiber/v2"
	"github.com/parental-control/backend/config"
)

type WebRTCHandler struct {
	cfg *config.Config
}

func NewWebRTCHandler(cfg *config.Config) *WebRTCHandler {
	return &WebRTCHandler{cfg: cfg}
}

type ICEServer struct {
	URLs       []string `json:"urls"`
	Username   string   `json:"username,omitempty"`
	Credential string   `json:"credential,omitempty"`
}

func (h *WebRTCHandler) GetRTCConfig(c *fiber.Ctx) error {
	servers := []ICEServer{
		{
			URLs: []string{h.cfg.TurnStunURL},
		},
		{
			URLs:       []string{h.cfg.TurnURL},
			Username:   h.cfg.TurnUsername,
			Credential: h.cfg.TurnCredential,
		},
	}

	return c.JSON(fiber.Map{
		"ice_servers": servers,
	})
}
