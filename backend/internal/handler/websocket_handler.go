package handler

import (
	"log"

	"github.com/gofiber/contrib/websocket"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/parental-control/backend/config"
	"github.com/parental-control/backend/internal/repository"
	"github.com/parental-control/backend/pkg/jwt"
)

type WSHandler struct {
	hub  *WSHub
	repo *repository.Repository
	cfg  *config.Config
}

func NewWSHandler(hub *WSHub, repo *repository.Repository, cfg *config.Config) *WSHandler {
	return &WSHandler{hub: hub, repo: repo, cfg: cfg}
}

// UpgradeCheck checks WebSocket upgrade headers and authenticates client
func (h *WSHandler) UpgradeCheck() fiber.Handler {
	return func(c *fiber.Ctx) error {
		if websocket.IsWebSocketUpgrade(c) {
			token := c.Query("token")
			deviceSecret := c.Query("device_secret")
			deviceID := c.Query("device_id")

			if token != "" {
				// Parent authentication via JWT
				claims, err := jwt.ParseToken(token, h.cfg.JWTSecret)
				if err != nil {
					return fiber.ErrUnauthorized
				}
				c.Locals("client_role", ClientRoleParent)
				c.Locals("client_id", claims.UserID.String())
				if claims.FamilyID != nil {
					c.Locals("family_id", claims.FamilyID.String())
				}
				return c.Next()
			} else if deviceID != "" && deviceSecret != "" {
				// Kid Agent authentication via device_id and secret
				devUUID, err := uuid.Parse(deviceID)
				if err != nil {
					return fiber.ErrUnauthorized
				}
				dev, err := h.repo.GetDeviceByID(c.Context(), devUUID)
				if err != nil || dev == nil || dev.PairingSecret != deviceSecret {
					return fiber.ErrUnauthorized
				}
				c.Locals("client_role", ClientRoleKid)
				c.Locals("client_id", dev.ID.String())
				c.Locals("family_id", dev.FamilyID.String())
				return c.Next()
			}

			return fiber.ErrUnauthorized
		}
		return fiber.ErrUpgradeRequired
	}
}

// HandleWS processes messages on established WebSocket
func (h *WSHandler) HandleWS() fiber.Handler {
	return websocket.New(func(c *websocket.Conn) {
		role, _ := c.Locals("client_role").(ClientRole)
		clientID, _ := c.Locals("client_id").(string)
		familyID, _ := c.Locals("family_id").(string)

		var connID string
		if role == ClientRoleParent {
			connID = uuid.New().String()
		} else {
			connID = clientID
		}

		client := &Client{
			ID:       connID,
			UserID:   clientID,
			FamilyID: familyID,
			Role:     role,
			Conn:     c,
			Send:     make(chan []byte, 256),
		}

		h.hub.register <- client

		// Read pump
		go func() {
			defer func() {
				h.hub.unregister <- client
				c.Close()
			}()

			for {
				_, msg, err := c.ReadMessage()
				if err != nil {
					if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
						log.Printf("WS unexpected close: %v", err)
					}
					break
				}
				h.hub.RouteMessage(client, msg)
			}
		}()

		// Write pump
		for msg := range client.Send {
			if err := c.WriteMessage(websocket.TextMessage, msg); err != nil {
				break
			}
		}
	})
}
